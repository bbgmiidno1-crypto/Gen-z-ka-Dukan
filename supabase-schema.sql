-- GEN Z KA DUKAN: Supabase database setup
-- Run this entire file in Supabase Dashboard > SQL Editor.
-- First create your owner account in Supabase Authentication (Phone + Password),
-- with phone confirmations disabled. Then replace OWNER_AUTH_USER_UUID below
-- with that account's Auth user UUID and run the final UPDATE statement.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  phone text unique,
  is_admin boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null default 'Men',
  price numeric(10,2) not null check (price >= 0),
  description text default '',
  images text[] not null default '{}',
  variants jsonb not null default '[]'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id),
  product_id uuid references public.products(id),
  product_name text not null,
  price numeric(10,2) not null,
  size text not null,
  colour text not null,
  customer_name text not null,
  phone text not null,
  pincode text not null,
  state text not null,
  district text not null,
  city text not null,
  address text not null,
  payment_method text not null default 'COD' check (payment_method = 'COD'),
  payment_status text not null default 'pending',
  status text not null default 'new' check (status in ('new','confirmed','packed','shipped','delivered','cancelled')),
  created_at timestamptz not null default now()
);

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public
as $$ select exists(select 1 from public.profiles where id = auth.uid() and is_admin = true); $$;

alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;

drop policy if exists "profiles read own" on public.profiles;
create policy "profiles read own" on public.profiles for select to authenticated using (id = auth.uid() or public.is_admin());
drop policy if exists "profiles insert own" on public.profiles;
create policy "profiles insert own" on public.profiles for insert to authenticated with check (id = auth.uid() and is_admin = false);
drop policy if exists "admin manage profiles" on public.profiles;
create policy "admin manage profiles" on public.profiles for update to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "public read active products" on public.products;
create policy "public read active products" on public.products for select to anon, authenticated using (active = true or public.is_admin());
drop policy if exists "admin insert products" on public.products;
create policy "admin insert products" on public.products for insert to authenticated with check (public.is_admin());
drop policy if exists "admin update products" on public.products;
create policy "admin update products" on public.products for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists "admin delete products" on public.products;
create policy "admin delete products" on public.products for delete to authenticated using (public.is_admin());

drop policy if exists "customer read own orders" on public.orders;
create policy "customer read own orders" on public.orders for select to authenticated using (user_id = auth.uid() or public.is_admin());
drop policy if exists "admin update orders" on public.orders;
create policy "admin update orders" on public.orders for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- Customers can only create orders through this stock-checking RPC.
create or replace function public.place_cod_order(
 p_product_id uuid, p_size text, p_colour text,
 p_customer_name text, p_phone text, p_pincode text,
 p_state text, p_district text, p_city text, p_address text
) returns uuid
language plpgsql security definer set search_path = public
as $$
declare
 p public.products%rowtype;
 v jsonb;
 new_variants jsonb := '[]'::jsonb;
 order_id uuid;
 found_variant boolean := false;
begin
 if auth.uid() is null then raise exception 'Please login before ordering.'; end if;
 if length(regexp_replace(p_pincode, '\D', '', 'g')) <> 6 then raise exception 'Enter a valid 6-digit PIN code.'; end if;
 select * into p from public.products where id = p_product_id and active = true for update;
 if not found then raise exception 'Product is unavailable.'; end if;
 for v in select value from jsonb_array_elements(p.variants)
 loop
   if v->>'size' = p_size and v->>'colour' = p_colour then
     found_variant := true;
     if coalesce((v->>'stock')::int,0) < 1 then raise exception 'Selected size and colour is out of stock.'; end if;
     v := jsonb_set(v, '{stock}', to_jsonb((v->>'stock')::int - 1));
   end if;
   new_variants := new_variants || jsonb_build_array(v);
 end loop;
 if not found_variant then raise exception 'Selected size/colour combination is not available.'; end if;
 update public.products set variants = new_variants, updated_at = now() where id = p.id;
 insert into public.orders(user_id,product_id,product_name,price,size,colour,customer_name,phone,pincode,state,district,city,address)
 values(auth.uid(),p.id,p.name,p.price,p_size,p_colour,p_customer_name,p_phone,p_pincode,p_state,p_district,p_city,p_address)
 returning id into order_id;
 return order_id;
end $$;

grant execute on function public.place_cod_order(uuid,text,text,text,text,text,text,text,text,text) to authenticated;

-- Storage bucket for uploaded product photos.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('product-images','product-images',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do nothing;

drop policy if exists "public view product images" on storage.objects;
create policy "public view product images" on storage.objects for select to anon, authenticated using (bucket_id = 'product-images');
drop policy if exists "admin upload product images" on storage.objects;
create policy "admin upload product images" on storage.objects for insert to authenticated with check (bucket_id = 'product-images' and public.is_admin());
drop policy if exists "admin update product images" on storage.objects;
create policy "admin update product images" on storage.objects for update to authenticated using (bucket_id = 'product-images' and public.is_admin()) with check (bucket_id = 'product-images' and public.is_admin());
drop policy if exists "admin delete product images" on storage.objects;
create policy "admin delete product images" on storage.objects for delete to authenticated using (bucket_id = 'product-images' and public.is_admin());

-- After creating the owner account, run this separately:
-- update public.profiles set is_admin = true where id = 'OWNER_AUTH_USER_UUID';
-- Ensure the owner profile row exists first:
-- insert into public.profiles(id, phone, is_admin)
-- values ('OWNER_AUTH_USER_UUID', '+91XXXXXXXXXX', true)
-- on conflict(id) do update set is_admin = true;

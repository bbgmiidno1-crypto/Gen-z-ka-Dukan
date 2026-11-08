# Gen Z Ka Dukan — Website Starter

Is project mein customer-facing fashion store, direct Buy Now (no cart), COD-only checkout, phone/password login, PIN lookup, single-admin dashboard, photo upload aur size+colour stock management ka starter implementation diya gaya hai.

## 1) GitHub Pages par upload
1. GitHub par apna repository banao, example: `gen-z-ka-dukan`.
2. Is ZIP ke andar ki saari files repository ke root mein upload karo (ZIP file ko khud upload mat karna).
3. Repository → Settings → Pages → Deploy from a branch → `main` → `/ (root)` → Save.
4. Kuch minutes baad GitHub Pages URL active hoga.

## 2) Supabase backend setup (required for real orders/login/admin)
1. Supabase par new project banao.
2. Project → SQL Editor → `supabase-schema.sql` ka content paste karke Run karo.
3. Authentication → Providers → Phone enable karo. Phone confirmations/OTP confirmation ko disable karo, agar project settings mein option available ho. Strong password policy rakho. Phone + password sign-up/sign-in support ko apne project par test karo before public launch.
4. Project Settings → API se Project URL aur anon/public key copy karo.
5. `config.js` mein `PASTE_SUPABASE_PROJECT_URL` aur `PASTE_SUPABASE_ANON_KEY` replace karo. `service_role` key kabhi bhi website code mein mat daalna.
6. Owner account ko Supabase Auth mein create karo. Uska Auth user UUID copy karo. SQL Editor mein `profiles` row insert/update karke `is_admin=true` set karo (SQL file ke end mein example diya hai). Sirf tumhare account ko admin mark karna.
7. Real customer registration se pehle no-OTP phone/password flow ko test karo. Supabase phone provider configuration / region settings ke hisaab se no-confirmation sign-up available na ho to backend configuration adjust karni hogi; OTP flow enable mat karna if no-OTP is a hard requirement.

## 3) Current starter behaviour
- Supabase config blank ho to storefront demo products dikhata hai. Login, real COD order and admin upload tab tak work nahi karenge.
- Real checkout ke liye logged-in customer zaroori hai.
- PIN code lookup India Post public API se hota hai. Customer ko returned city/post office verify karna chahiye.
- Admin shortcut bottom-right ⚙ icon hai. Admin account ko SQL se `is_admin=true` mark karna zaroori hai.
- Product images Supabase Storage ke `product-images` bucket mein upload hoti hain.
- Stock variants mein har size + colour combination alag row hai.
- Order place hote waqt database RPC stock check aur decrement karta hai.
- COD only. No cart and no online payment gateway.

## 4) Important before public launch
- Phone/password auth without OTP must be tested end-to-end in your Supabase project.
- PIN lookup gives postal delivery area; it is not a courier serviceability guarantee. Integrate a courier/shipping provider before promising delivery availability.
- Add your real support email, WhatsApp number, shipping/return/privacy policy, taxes and shipping charges.
- Add image compression and stricter file-size controls if uploading many large photos.
- Consider order confirmation notifications and proper invoice/tax handling.
- Never expose Supabase service-role key in `config.js` or frontend code.

## Files
- `index.html` — storefront, login, COD checkout and admin UI
- `style.css` — responsive styling
- `app.js` — storefront and Supabase client logic
- `config.js` — Supabase public config
- `supabase-schema.sql` — tables, policies, stock-safe COD order function and storage policies

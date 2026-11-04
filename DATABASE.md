# Boinkers Fortune Club — Database Plan

## حالة المشروع قبل الربط

المشروع عبارة عن لعبة Telegram Mini App مبنية بـ React 19 وTanStack Start/Router وVite. الواجهة الحالية تحتوي على:

- ماكينة Slots مع رهانات `x1 / x3 / x5 / x10` ومكافآت coins/spins/tickets.
- Spin Pass مجاني/مدفوع، XP ومستويات ومكافآت.
- حدث رئيسي متغير كل 48 ساعة، وأحداث مباشرة متعددة مدتها 24 أو 48 ساعة.
- Wheel of Fortune بمضاعفات `x1 / x2 / x5 / x10` وجوائز spins وwheel tickets وTON.
- ترقية أجزاء الشخصية وMerge Board وإنتاج Solo.
- Tasks وReferrals وLeaderboard وShop.
- اتصال TON Wallet وواجهة NFT.

قبل هذه المرحلة كانت كل حالة اللاعب محفوظة في `localStorage`، وبعض بيانات الأحداث والمهام والعروض ثابتة في ملفات TypeScript. لذلك كان من السهل تعديل الرصيد من المتصفح أو فقدانه عند تغيير الجهاز، ولم تكن نتائج السحب قابلة للتدقيق.

## ما تم إنشاؤه

الأحداث ليست مجرد reset لنفس الحدث: كل Event جديد له `event_key` واسم وTheme وToken art ومدة و`scale` مختلف. أصول الأحداث الجديدة موجودة داخل `src/assets`، والواجهة تستخدمها من خلال `TOKEN_ART`.

تم تطبيق migration باسم `create_boinkers_game` على مشروع Supabase الموجود، مع عزل كامل عن الجداول الأخرى الموجودة في المشروع باستخدام prefix `boinkers_`.

الجداول الجديدة وعددها 16:

- `boinkers_players`: هوية Telegram وملف اللاعب والأرصدة والتقدم الأساسي.
- `boinkers_balance_ledger`: سجل غير قابل للتكرار لكل تغيير في coins/solo/spins/tickets/tokens/TON.
- `boinkers_slot_rounds`: كل دورة Slots والـ reels والنتيجة ومفتاح idempotency.
- `boinkers_wheel_rounds`: كل دورة Wheel والنتيجة والـ payout.
- `boinkers_tasks` و`boinkers_task_completions`: تعريف المهام وحالة إكمال كل لاعب.
- `boinkers_referrals`: علاقة الإحالة والمكافآت المدفوعة.
- `boinkers_events` و`boinkers_event_progress`: نسخ الأحداث ومتابعة tokens وtier claims.
- `boinkers_pass_claims` و`boinkers_milestone_claims`: منع المطالبة بالمكافأة أكثر من مرة.
- `boinkers_shop_products` و`boinkers_shop_orders`: المنتجات والشراء مع idempotency.
- `boinkers_wallet_transactions`: TON/Stars deposits, rewards, purchases, withdrawals.
- `boinkers_nft_items` و`boinkers_nft_orders`: كتالوج NFT وطلبات الشراء/mint.

تم تفعيل RLS على كل الجداول، ولا توجد صلاحية كتابة مباشرة من العميل. الخطوة التالية هي إضافة RPC/server functions تتحقق من Telegram init data وتنفذ السحب والشراء وتغيير الأرصدة داخل معاملات آمنة.

## قواعد الربط التي سنلتزم بها

1. **لا نثق في المتصفح:** المتصفح يطلب `spin` أو `wheel spin`، والسيرفر يختار النتيجة ويحسب المكافأة.
2. **Idempotency:** كل عملية تحمل مفتاحًا فريدًا؛ إعادة إرسال الطلب لا تعطي مكافأة ثانية.
3. **Ledger + snapshot:** الـ ledger هو سجل التدقيق، وحقول الأرصدة في `boinkers_players` snapshot سريع للعرض.
4. **Telegram identity:** `telegram_id` هو المفتاح الأساسي للاعب بعد التحقق من Telegram WebApp init data.
5. **أموال حقيقية:** لا يتم فتح TON purchase/withdrawal فعلي إلا بعد ربط wallet verification وwebhook/transaction confirmation.
6. **الـ leaderboard:** يقرأ من `boinkers_players.solo` مع index مخصص، ولا يعتمد على بيانات تجريبية.
7. **المهام:** المكافأة تصرف مرة واحدة بعد verification، وليس بمجرد الضغط على زر GO.

## ترتيب التنفيذ التالي

### المرحلة 1 — اللاعب والتحميل

إضافة Supabase client/server helpers، والتحقق من Telegram WebApp init data، وإنشاء/تحميل `boinkers_players` بدل `localStorage`.

### المرحلة 2 — Slots وWheel

إضافة server functions/RPC للخصم، اختيار النتيجة، إنشاء round، وإضافة ledger entries في transaction واحدة. بعد ذلك إزالة `rnd()` وعمليات `grant/spend` الحساسة من مسار العميل.

### المرحلة 3 — Progression

نقل Spin Pass، milestones، الأحداث، event claims، regeneration وSolo claim إلى معاملات server-side مع اختبارات idempotency.

### المرحلة 4 — Tasks / Referrals / Shop

ربط بيانات المهام والعروض من الجداول، إضافة verification حقيقي للمهام المدعومة، ثم referral rewards وorders.

### المرحلة 5 — Wallet / NFT / Admin

إضافة wallet signature verification، payment callbacks، سجل المعاملات، NFT order state machine، ثم لوحة إدارة لتعديل tasks/products/events دون تعديل الكود.

## ملاحظة مهمة

قاعدة البيانات أصبحت جاهزة ومعزولة، لكن الواجهة لم تُربط بها بعد في هذه المرحلة. هذا مقصود حتى لا نحول اللعبة إلى نظام نصفه server-side ونصفه local ويحدث تضارب أو مضاعفة مكافآت. بعد اعتماد تدفق Telegram authentication وطريقة الدفع المطلوبة، يتم تنفيذ الربط على مراحل مع الحفاظ على الواجهة الحالية.

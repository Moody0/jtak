# JTAK UI/UX Redesign Journey & Standing Directives

> **Living Project Document**
> This file acts as the single source of truth for all permanent user instructions, UI/UX design rules, honest design critiques, aesthetic decisions, and modernization milestones throughout the JTAK project lifecycle.

---

## 🎯 Role Definition & Mission

- **Role**: Senior UI/UX Designer & Lead Flutter / Frontend Engineer.
- **Dual Responsibility**: 
  1. **Design Leadership**: Uncompromising UI/UX direction, honest critiques, design system architecture, micro-interactions, accessibility, and visual polish.
  2. **Engineering Execution**: Writing clean, robust, highly performant, null-safe, production-ready Flutter/Dart & web code, modularizing reusable widgets, optimizing rendering performance, and managing state cleanly.
- **Tone & Mindset**: Proactive, opinionated, uncompromising on quality, detail-oriented, and radically honest.

---

## 📜 Standing Rules & Working Directives

### 1. ⚡ 100% Radical Candor & Honest Critique (Priority #1)
- **Zero Hesitation**: If any suggestion, user idea, existing screen layout, or UX pattern looks dated, cluttered, awkward, or suboptimal, call it out immediately.
- **Constructive Design Rationale**: Always explain *why* something doesn't work (visual hierarchy, cognitive load, accessibility, thumb-reach zone, modern design trends) and provide a concrete, superior alternative.
- **Never Settle for "Good Enough"**: Challenge generic defaults, boring layouts, and outdated patterns.

### 2. 🎨 Modern Design & Craftsmanship Standards
- **Typography with Personality**: Intentional font pairing, strict scale, crisp weights, and comfortable line-heights.
- **Harmonious Color Palette**: Refined primary/accent hues, clean neutral grays, subtle surface elevations, avoiding harsh saturated clashes.
- **Spacious & Breathable**: 8pt grid system, generous whitespace, structured card layouts, rounded corners (12–20px radii), soft shadows.
- **Tactile & Fluid Micro-Interactions**: Delightful feedback on touch/click, smooth transitions, subtle haptics, skeleton loaders, engaging empty states.
- **Intuitive UX Architecture**: Minimal friction, clear call-to-actions (CTAs), progressive disclosure, thumb-friendly navigation.

### 3. 📝 Persistent Directives Log
Every instruction, preference, or constraint given by the user will be recorded in the [User Directives & Preferences Log](#user-directives--preferences-log) below to guarantee zero regression across sessions.

---

## 📋 User Directives & Preferences Log

| # | Date | Category | Directive / Instruction | Status | Notes / Impact |
|---|------|----------|-------------------------|--------|----------------|
| **01** | 2026-08-14 | **Critique & Process** | **100% Honesty Policy**: Provide direct, unfiltered senior UI/UX feedback. If an idea or design is weak, speak up immediately and propose a better alternative. | 🟢 Active | Applied across all reviews, planning, and code changes. |
| **02** | 2026-08-14 | **Documentation** | **Journey Tracker**: Maintain this `.md` file with every rule, directive, and design evolution note. | 🟢 Active | Updated on every new user requirement. |
| **03** | 2026-08-14 | **Brand & Visuals** | **Dominant Orange Palette**: Orange (`#FF5400` / `#FA5A2A`) is the **primary dominant brand color**, paired with Deep Midnight Charcoal (`#111827`) for razor-sharp typography, Soft Peach (`#FFF3EB`) for surface tints, and eliminating dated corporate navy. | 🟢 Active | Replaces old navy blue with a modern, appetite-stimulating brand system. |
| **04** | 2026-08-14 | **Feature Pillars** | **Core On-Demand Delivery Pillars**: Anchor all redesigns around the 6 core pillars: (1) Fast & Frictionless UI, (2) Real-Time GPS Tracking, (3) Diverse Payments, (4) Ratings & Reviews, (5) Instant Offers & Rich Notifications, (6) Seamless Bilingual Support (Arabic & English RTL/LTR). | 🟢 Active | Benchmarked against top regional apps. |
| **05** | 2026-08-14 | **Market & Localization** | **Syrian Market Focus (SYP)**: Tailored for Syria (Syrian Pound `ل.س`, Syriatel Cash / MTN Cash / Local Gateways / Cash on Delivery, landmark-assisted address forms, and low-latency network optimizations). | 🟢 Active | Crucial for currency formatting (large integers), payments, and address inputs. |
| **06** | 2026-08-14 | **Design System** | **Typography & Grid Spec**: Adopt **IBM Plex Sans Arabic** (Regular 400, Medium 500, SemiBold 600, Bold 700) with tailored line-heights (1.25 for UI, 1.5 for copy) and a **6-Column Grid (16px Margin / 16px Gutter)** on an 8pt base. | 🟢 Active | Standardized across all Flutter UI components. |
| **07** | 2026-08-14 | **Flow Scope & Simplification** | **Streamlined Direct Ordering (Removed Group System & Chat)**: Scope narrowed to remove multi-user group orders and in-app chat. Kept the gamified **Wheel Game** as an individual discovery feature ("محتار شو تاكل؟"). Focus on lightning-fast single-user discovery, menu customization, 1-page checkout, and live GPS tracking. | 🟢 Active | Greatly reduces app complexity, eliminates friction, and speeds up ordering UX. |
| **08** | 2026-08-14 | **Component Library** | **JTAK Atomic Component System**: Implement the complete design system matching the UI specs with Orange (`#FF5400`) brand theme and SYP (`ل.س`) currency. Includes: Header address bar, Search pill, Restaurant/Meal cards with in-image `+` add, Segmented order type buttons, Status chips, Category sticky tabs, Cart steppers, Driver card, 4-stage tracking timeline, and Address bottom sheets. | 🟢 Active | Standardized reusable Flutter widget library. |

---

## 📱 JTAK Ecosystem Overview

The JTAK codebase consists of the following components:

| Module | Tech Stack | Description | Target Focus |
|--------|------------|-------------|--------------|
| `jtak-mobile-master` | Flutter / Dart | Main Customer Mobile App (Shopping, Catalog, Cart, Tracking) | Primary UI/UX Overhaul |
| `jtak-mobile-delivery-master` | Flutter / Dart | Driver / Delivery Agent App | Ergonomic & Fast Dispatch UX |
| `jtak-mobile-warehouse-master` | Flutter / Dart | Warehouse & Inventory Operations | High-efficiency Workflow UX |
| `jtak-dashboard-main` | Angular / TypeScript | Admin Management Portal | Data Density & Clean Admin UX |
| `jtak-landing-master` | Web / HTML / Tailwind / JS | Public Marketing Landing Page | High-converting Showcase |
| `jtak-backend-main` | Backend APIs / Services | Core Business Logic & Data Layer | API integration |

---

## 🔍 UI/UX Audit & Modernization Roadmap

### Phase 1: Customer App Foundation & Theme Modernization (`jtak-mobile-master`)
- [ ] **Design Tokens & Palette**: Modernize primary blue (`#253784`), orange accent (`#D05311`), and establish a refined dark/light neutral palette, elevation system, and typography scale.
- [ ] **Navigation & Shell**: Redesign bottom navigation bar, header app bars, search bar, and drawer for a slick, modern feel.
- [ ] **Home & Discovery Screen**: Overhaul hero banners, category carousels, flash deals, and product card layouts.
- [ ] **Product Catalog & Detail**: Interactive image galleries, clean variant pickers, sticky bottom action bars, trust badges.
- [ ] **Cart & Checkout Flow**: Frictionless checkout, clean address selectors, order summary cards, clear payment state feedback.
- [ ] **Orders & Live Tracking**: Real-time step tracker, rider status card, interactive delivery map UX.
- [x] **User Account & Profile**: Clean settings grouped lists, modern avatar selector, order history tabs.

### Phase 2: Micro-Interactions, Feedback & Polish
- [ ] **Skeleton Loaders & Shimmers**: Replace blank or generic spinners with smooth shimmer placeholders.
- [ ] **Empty & Error States**: Expressive illustrations, clear recovery actions, delightful micro-copy.
- [ ] **Dialogs, Bottom Sheets & Modals**: Smooth slide animations, draggable sheets, modern rounded aesthetic.

---

## 🏛️ The 6 Core Feature Pillars & Senior UX Blueprint

```
       ┌─────────────────────────────────────────────────────────┐
       │             JTAK ON-DEMAND DELIVERY ENGINE              │
       └─────────────────────────────────────────────────────────┘
        │            │             │            │            │
 ┌──────▼─────┐┌─────▼──────┐┌─────▼─────┐┌─────▼─────┐┌─────▼─────┐
 │ 1. FAST UI ││ 2. LIVE GPS││ 3.PAYMENTS││ 4. REVIEWS││ 5. OFFERS │
 │ - 3-step   ││ - Realtime ││ - ApplePay││ - Ratings ││ - Flash   │
 │   checkout ││   polyline ││ - STC Pay ││ - Photo tag││   deals  │
 │ - Stepper  ││ - Rider ETA││ - Mada/COD││ - Verified││ - Rich    │
 │   cards    ││ - Call/Chat││ - 1-tap   ││   badges  ││   pushes  │
 └────────────┘└────────────┘└───────────┘└───────────┘└───────────┘
        └──────────────────────────┬──────────────────────────┘
                         ┌─────────▼─────────┐
                         │ 6. BILINGUAL AR/EN│
                         │ Native RTL / LTR  │
                         │ Tajawal / Inter   │
                         └───────────────────┘
```

| Pillar | UX Objective | Senior Designer Critique & Implementation Strategy |
|--------|--------------|----------------------------------------------------|
| **1. Simple & Fast UI** | Reduce time-to-cart & checkout clicks | • In-card `+`/`-` steppers (zero navigation needed for re-ordering).<br>• Sticky bottom mini-cart floating bar showing live count & total.<br>• 1-page accordion checkout instead of a multi-screen labyrinth. |
| **2. Real-Time GPS Tracking** | Customer peace of mind & trust | • Live animated map with rider pulsing marker, delivery route polyline, and estimated arrival minutes countdown.<br>• 4-phase visual status bar: *Placed ➔ Preparing ➔ On the Way ➔ Delivered*.<br>• Instant 1-tap call/WhatsApp driver floating action button. |
| **3. Diverse Local Payments** | Zero payment friction & abandoned carts | • Syrian Market Payment Matrix: Cash on Delivery (الدفع عند الاستلام), Syriatel Cash (سيريتل كاش), MTN Cash (إم تي إن كاش), Bemo/Local Bank Gateway, and In-App Wallet balance (محفظتي).<br>• Visual payment cards with recognizable local telecom & payment branding. |
| **4. Ratings & Reviews** | Social proof and merchant quality | • Quick 5-star tap modal after order delivery with optional emoji tags (e.g. ⚡ Fast Delivery, 📦 Great Packaging, 🌟 Hot & Fresh).<br>• Verified buyer badge on reviews to build rock-solid trust. |
| **5. Instant Offers & Alerts** | High retention & basket size | • Dynamic countdown timers on flash deal banners.<br>• Cart drawer upsell recommendations ("Add $3.00 more for Free Delivery").<br>• Rich push notifications with promo codes and direct deep links. |
| **6. Multi-Language (AR/EN)** | Seamless RTL/LTR switching | • True bidirectional layout design (mirrored icons, padding, and alignments).<br>• Typography: **Tajawal** or **Readex Pro** for Arabic, paired with **Inter** or **Plus Jakarta Sans** for English. |

---

## ⚡ Streamlined Customer Ordering & Discovery Flow

```
  ┌─────────────────┐
  │  SPLASH SCREEN  │
  └────────┬────────┘
           │ (Fast transition / Guest browse)
  ┌────────▼─────────────────────────────────────────────────┐
  │                       HOME SCREEN                         │
  │ • Delivery Location Header (Damascus / Neighborhood)      │
  │ • Animated Search & Filters ("ابحث عن شاورما، برغر...")   │
  │ • Dynamic Banners & Flash Deals                          │
  │ • 🎡 "محتار شو تاكل؟" (Gamified Wheel of Restaurants)   │
  │ • Categories Grid (4-col / 16px)                          │
  │ • Featured / Popular Restaurants & Stores                 │
  └────────┬─────────────────────────┬───────────────────────┘
           │ (Search / Category)     │ (Wheel Spin Win)
  ┌────────▼──────────────┐          │
  │   RESTAURANT LIST     │◄─────────┘
  └────────┬──────────────┘
           │
  ┌────────▼──────────────┐
  │   RESTAURANT MENU     │ (Sticky Category Tabs, Search within menu)
  └────────┬──────────────┘
           │ (Tap Dish)
  ┌────────▼──────────────┐
  │  MEAL CUSTOMIZATION   │ (Sizes, Sides, Sauces, Cooking Notes, In-modal Stepper)
  └────────┬──────────────┘
           │
  ┌────────▼──────────────┐
  │  FLOATING CART PILL   │ ("🛒 2 Items • 75,000 ل.س • عرض السلة")
  └────────┬──────────────┘
           │
  ┌────────▼──────────────┐
  │   CART / CHECKOUT     │ (1-Page Accordion: Address/Landmark, Delivery Notes, 
  │                       │  Syriatel/MTN/Cash, Promo Code, Total Summary)
  └────────┬──────────────┘
           │ (Place Order ➔ Auth prompt if guest)
  ┌────────▼──────────────┐
  │  LIVE ORDER TRACKING  │ (Map with Route Polyline, 4-step Timeline, Driver Call)
  └────────┬──────────────┘
           │ (Delivered)
  ┌────────▼──────────────┐
  │  1-TAP RATING MODAL   │ (5 Stars + Quick Tags + Tip)
  └───────────────────────┘
```

---

## 🎨 JTAK Atomic Component Library (Design & Engineering Spec)

Adapted from the approved component sheets to JTAK's **Navy Blue (`#253784`)** + **Energetic Orange (`#F05A22`)** theme and **Syrian Pound (`ل.س`)** localization:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 1. TOP APP BAR                                                              │
│ [ JTAK Logo ]                     [ 📍 دمشق - المزة، جانب مشفى الرازي ⌵ ]    │
├─────────────────────────────────────────────────────────────────────────────┤
│ 2. SEARCH BAR                                                               │
│ [ 🔍 ابحث عن المطاعم، الوجبات أو الحلويات...                              ] │
├─────────────────────────────────────────────────────────────────────────────┤
│ 3. SEGMENTED ORDER SWITCHER                                                 │
│ [ ✓ التوصيل الآن (نشط) ]   [ ⏱️ جدولة الطلب ]   [ 🛍️ استلام بنفسك ]        │
├─────────────────────────────────────────────────────────────────────────────┤
│ 4. RESTAURANT & MEAL CARDS                                                  │
│ ┌───────────────────────────────────┐ ┌───────────────────────────────────┐ │
│ │ [Cover Photo + Logo Badge]        │ │ [Dish Photo]                 [ + ]│ │
│ │ الشام زمان            ⚡ مفتوح    │ │ شاورما دجاج إكسترا مع بطاطا       │ │
│ │ شاورما، مشاوي • 4.8 ⭐ (520)      │ │ 45,000 ل.س                        │ │
│ │ ⏱️ 25-35 دقيقة • 🚗 5,000 ل.س     │ │ ⏱️ 20-30 دقيقة • 1.5 كم           │ │
│ └───────────────────────────────────┘ └───────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────────────┤
│ 5. CHIPS & STATUS BADGES                                                    │
│ [ 🟢 مفتوح ]  [ 🟡 مشغول ]  [ 🔴 مغلق ]  [ 🚗 5,000 ل.س ]  [ 🏷️ خصم 20% ]   │
├─────────────────────────────────────────────────────────────────────────────┤
│ 6. STICKY CATEGORY TABS (Menu)                                              │
│ [ جديدنا (خط كحلي سفلي) ]   [ الساندوتشات ]   [ الوجبات الرئيسية ]  [ المشروبات ]│
├─────────────────────────────────────────────────────────────────────────────┤
│ 7. CART ITEM ROW & STEPPERS                                                 │
│ [ - 2 + ]   شاورما دجاج (عرض الإضافات ⌵)     [صورة]    90,000 ل.س           │
├─────────────────────────────────────────────────────────────────────────────┤
│ 8. DRIVER ASSOCIATE CARD                                                    │
│ [Avatar] أحمد سامي (4.9 ⭐)       [ 📞 اتصال بالمندوب ]  [ 💬 محادثة/واتساب ] │
├─────────────────────────────────────────────────────────────────────────────┤
│ 9. 4-PHASE ORDER TRACKING TIMELINE                                          │
│ ●─── تم الاستلام  ➔  ●─── جاري التحضير  ➔  ●─── في الطريق  ➔  ●─── تم التوصيل │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 💡 Senior Design Log & Critique Notes

### 2026-08-14: Theme Foundation & Top App Bar Implementation
* **Theme Modernization**:
  * Upgraded primary palette from dated 2017 corporate navy to **Dominant Sunset Orange (`#FF5400`)** paired with **Deep Midnight Charcoal (`#111827`)** for razor-sharp typography contrast and **Soft Peach (`#FFF3EB`)** for chip/surface tints.
  * Integrated **IBM Plex Sans Arabic** across the entire text theme with dedicated line-heights (1.25 for compact UI, 1.45 for copy) and standard weights (400, 500, 600, 700).
  * Upgraded default card radii from 5px to **16px** with subtle diffuse ambient shadows (`#0A000000`) and 1px micro-border strokes (`#F1F5F9`).
* **Top App Bar Component (`top_app_bar_widget.dart`)**:
  * **Brand Mark**: JTAK brand container + Arabic wordmark (`جيتك`) with vibrant orange badge.
  * **Delivery Location Dropdown**: Rounded peach pill (`#FFF3EB`) displaying current destination ("دمشق، المزة...") with location pin and dropdown arrow.
  * **Interactive Address Bottom Sheet (`showJtakAddressBottomSheet`)**: 24px rounded sheet with saved addresses (Home, Work), radio checks, and "+ إضافة عنوان جديد" action.
  * **Cart Action Badge**: 44x44 elevated circular action container with live cart count pill badge.
  * **Sliver Integration**: Provided `JtakSliverAppBar` for smooth floating/pinned scroll in `home_page.dart`.
* **Search Bar Component (`search_bar_widget.dart`)**:
  * 52px rounded pill with `#EEEEEE` surface, right-aligned search icon placed directly before the 15.5px medium placeholder text.
* **Featured Categories Grid (`featured_categories_grid.dart`)**:
  * **3-Column Grid** displaying **max 6 categories** (2 rows of 3 items).
  * Tuned aspect ratio (1.22) horizontal rounded image containers with soft neutral `#F4F4F6` surface background and centered category imagery.
  * Bold, centered Arabic labels in **IBM Plex Sans Arabic** (14px, FontWeight.w700) below each image card.
  * Optional promo / discount badge overlays (e.g. `خصم 20%`).
  * Integrated seamlessly as `SliverJtakFeaturedCategories` into `home_page.dart`.
* **Daily Offers Section (`daily_offers_section.dart`)**:
  * **Section Header**: Right-aligned `"العروض اليومية"` in **IBM Plex Sans Arabic** (19px, FontWeight.w800).
  * **Banner Slider**: 20px rounded landscape cards with manual clamping horizontal scroll (no overscroll stretch distortion).
  * **Expanding Fill Progress Bar**: Anchored to the right and expands towards the left as you scroll until 100% fully filled at the end.
* **Restaurant & Meals 3-Card Component System (`restaurant_card_widget.dart` / `meal_card_widget.dart`)**:
  * **Card Design 1 (Prime / Sponsored Restaurant)**: Cover photo + floating merchant logo + left-side `Prime` / Free Delivery badge stack. Used for: *Sponsored / Promoted restaurants & top of search results*.
  * **Card Design 2 (Standard Restaurant Card - `JtakRestaurantCard`)**: Cover photo + floating merchant logo + floating distance pill (`📍 5.8 كم`) + verified badge + rating (`⭐ 4.9 (412) • ⏱️ 15-25 دقيقة`) + delivery fee chip (`🚗 5,000 ل.س`). Used for: *Home Page "مطاعم بالقرب منك" (Nearby Restaurants) & Main Discovery Feed*.
  * **Card Design 3 (Meal / Dish Card with in-image quick `+` add)**: Food cover + quick add `+` button + dish title + price in `ل.س` + ETA/distance. Used for: *Trending Meals on Home Page & Restaurant Menu screens*.
* **Nearby Restaurants Section (`nearby_restaurants_section.dart`)**:
  * Header row with title `"مطاعم بالقرب منك"` and brand action link `"عرض الكل >"`.
  * Horizontal carousel of Standard Restaurant Cards (`JtakRestaurantCard`).
* **Delivery Offers Section (`delivery_offers_section.dart`)**:
  * Header row with title `"توصيل مجاني"` and brand action link `"عرض الكل >"`.
  * Horizontal carousel of **Meal / Dish Quick-Add Cards** (`JtakMealCard` - Card Design #3) featuring floating Merchant Logo (Bottom-Right), floating Quick-Add `+` button (Bottom-Left), bold dish titles, bold red price in `ل.س`, and `ETA | Distance` metadata anchored firmly to the bottom.
* **Various Cuisines Section (`various_cuisines_section.dart`)**:
  * Header row with title `"مطابخ متنوعة"`.
  * Horizontal scrolling row of compact category cards (`82x76` image box with `16px` rounded corners + bold Arabic label).
  * Real-time expanding scroll progress fill bar anchored to the right.
* **Restaurant Menu Page (`restaurant_menu_page.dart`)**:
  * **Section 1: Banner Header**: High-res cover with circular floating back & search actions, and status pill (`⚡ مفتوح حتى 3 ص`).
  * **Section 2: Overview Card**: Brand logo, name, `Prime ✓` badge, 3-Way Segmented Order Switcher (`التوصيل الآن` | `جدولة الطلب` | `استلام بنفسك`), and 3-column fee metrics row.
  * **Section 3: Reviews Card**: Rating badge (`⭐ 4.3`), customer feedback quote with avatar, and soft peach `"عرض الكل <"` button.
  * **Section 4: Sticky Category Tabs Bar & 2-Column Menu Grid**: Sticky horizontal tabs (`جديدنا`, `السندوتشات`, `الوجبات الرئيسية`, `سطل العائلة`) and 2-column food cards with in-image quick-add (`+`) buttons.

### 2026-08-17: Customer Account & Profile Screen Overhaul (`account_page.dart`, `account_widget.dart`, `profile_page.dart`, `social_media_widget.dart`)
* **Radical Critique of Previous UI**:
  * The old screen was a barren white screen with raw hairline dividers, plain orange list text, floating generic SVG icons, and a low-converting, empty guest state.
  * Lacked structured visual hierarchy, category grouping, interactive quick metrics, and consistent micro-interactions.
* **Modernized Implementation**:
  1. **Dual-State Hero Identity Component (`account_widget.dart`)**:
     * **Logged-in State (`AccountCard`)**: Elevated card with subtle border (`0.9px #E2E8F0`), soft ambient shadow, vibrant orange gradient avatar ring (`#FF5400` ➔ `#FF8C42`), user name, verified badge pill (`✓ موثق`), locked phone number, and a sleek `"تعديل"` edit pill action.
     * **Embedded Quick-Action Bar**: 3 interactive shortcut capsules (📦 **طلباتي** ➔ fast-jumps to Orders tab, 📍 **عناويني** ➔ opens Saved Addresses, ❤️ **المفضلة** ➔ fast-jumps to Favorites).
     * **High-Converting Guest State (`GuestAccountCard`)**: Warm peach gradient canvas (`#FFF7F2` ➔ `#FFF0E6`) with glowing user avatar graphic, friendly Arabic copy (*"مرحباً بك في جيتك 👋"*), and a full-width vibrant Orange Gradient CTA button (*"تسجيل الدخول / حساب جديد"*).
  2. **Structured Grouped Card Sections (`account_page.dart`)**:
     * **النشاط والمعاملات (Activity & Orders)**: Grouped card with Orders History, Saved Delivery Addresses, and Favorites.
     * **الإعدادات والتفضيلات (Preferences & Settings)**: Notifications with unread badge counter and App Language modal switcher (`العربية / English`).
     * **المساعدة والدعم القانوني (Support & Help Center)**: Interactive bottom sheet with 1-tap WhatsApp chat and direct customer service phone call, About JTAK, Terms & Privacy policy, and App Store rating.
     * **إجراءات الحساب (Account Actions)**: Clean danger-styled Logout button with modern dialog confirmation.
  3. **Refined Social Media & Brand Hub (`social_media_widget.dart`)**:
     * Modern card footer with 5 pastel circular brand icon buttons (WhatsApp, Direct Call, Facebook, Instagram, YouTube) with haptic feedback and safe deep-link URL launching.
     * Brand footer tag: `جيتك JTAK Delivery • الإصدار 1.0.3` • `صُنع بكل ❤️ لتوصيل أسرع وألذ في سورية`.
  4. **Modernized Profile Edit Screen (`profile_page.dart`)**:
     * Centered avatar hero with gradient border and floating camera badge.
     * Modern bordered text inputs (`#F8FAFC` fill, `#E2E8F0` border, `#FF5400` focus) with SolarIcons prefix icons.
     * Locked phone number notice with security shield and full-width gradient Save button.














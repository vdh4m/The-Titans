# 📚 StudyHub — Smart Educational Platform

**StudyHub** is a full-featured Flutter mobile application designed to revolutionize the educational experience for Egyptian university students and doctors (professors). It bridges the gap between students and educators by providing a unified platform for course management, AI-powered study tools, real-time communication, and smart productivity features.

---

## 🎯 Problem

- Students struggle to find organized, reliable academic resources for their specific university and faculty.
- There is no single platform that combines course materials, live meetings, AI study tools, and community interaction.
- Doctors (professors) lack an efficient way to distribute materials, host meetings, and manage quizzes for their students.

## 💡 Solution

StudyHub provides a **dual-role platform** (Student & Doctor) with:

- **Structured course management** with file uploads (PDFs, images, videos, docs) via Supabase.
- **In-app file viewing** — PDFs stream directly inside the app using `SfPdfViewer.network`, images via `PhotoView`, videos via `Chewie`, and documents via embedded Google Docs Viewer (WebView).
- **Live meetings** powered by Jitsi Meet, launched securely in-app via Chrome Custom Tabs / Safari View Controller for 100% crash-free stability.
- **AI-powered tools** using Google Gemini API — including mock exams, note summarization, quiz generation, flashcards, smart revision, and PDF summarization.
- **Community features** — study groups, group chat, Q&A community board, and study battles (gamification).
- **Productivity tools** — study timer with focus mode (DND), task manager, exam countdown, GPA tracker, course roadmap, weekly reports, leaderboard, mood selector, and CV builder.
- **Offline mode** — download and access materials without internet using Hive local storage.
- **Premium subscription system** with Paymob payment integration and paywall gating.
- **Bilingual support** — full Arabic & English localization with RTL layout support.
- **Dark mode** — premium dark theme with a carefully crafted color palette.

---

## 🏗️ Architecture & Tech Stack

| Layer          | Technology                                                       |
| -------------- | ---------------------------------------------------------------- |
| **Framework**  | Flutter 3.x (Dart 3.x)                                          |
| **State**      | Provider (`AuthProvider`, `AppProvider`, `StudyProvider`)         |
| **Backend**    | Firebase (Auth, Firestore, Storage, Messaging)                   |
| **AI**         | Google Gemini API (`google_generative_ai`)                       |
| **Storage**    | Supabase (file uploads), Hive (offline cache)                  |
| **Payments**   | Paymob integration                                               |
| **Meetings**   | Jitsi Meet via `url_launcher` (inAppWebView)                     |
| **PDF Viewer** | Syncfusion Flutter PDF Viewer (network streaming)                |
| **Video**      | `video_player` + `chewie`                                        |
| **Image**      | `photo_view` (pinch-zoom, pan)                                   |
| **Docs**       | `webview_flutter` via Google Docs Viewer                         |
| **TTS**        | `flutter_tts` (Text-to-Speech)                                   |
| **OCR**        | `google_mlkit_text_recognition` (camera-based text extraction)   |
| **Networking** | `dio`, `http`                                                    |
| **Navigation** | Cupertino-style smooth page transitions globally                 |

---

## 📱 Screens & Features

### 🔐 Authentication
- **Welcome Screen** — app intro with role selection
- **Login / Register** — separate flows for Students and Doctors
- **Doctor Registration** — includes multi-position university/faculty dropdown selection from a comprehensive Egyptian universities dataset
- **Auto-login** — persistent session via Firebase Auth state
- **Pending Approval** — doctors await admin verification before accessing the platform

### 🏠 Home
- **Home Screen** — personalized dashboard with course overview, stats, and quick actions
- **Notification Center** — push notifications via Firebase Messaging
- **Main Screen** — smooth cross-fading bottom navigation with animated tab switching

### 📖 Courses
- **Courses Screen** — browse and manage enrolled/created courses
- **Course Detail** — view materials, quizzes, and meeting schedules
- **Upload Material Dialog** — doctors upload PDFs, images, videos, and documents to Supabase
- **File Viewer** — universal in-app viewer:
  - **PDF** → `SfPdfViewer.network` (direct streaming, no download required)
  - **Images** → `PhotoView` with pinch-zoom
  - **Videos** → `Chewie` + `video_player`
  - **Docs/PPT/XLS** → Google Docs Viewer embedded via `WebView`
- **In-App Meetings** — Jitsi Meet rooms launched via `url_launcher` in Chrome Custom Tabs (zero crashes)
- **Quizzes** — doctors create quizzes, students take them with instant scoring

### 🧠 AI Tools
- **AI Assistant Screen** — chat with Google Gemini for study help
- **Mock Exam Generator** — AI-generated practice exams based on course content
- **Note Summarizer** — condense lecture notes using AI
- **Quiz Generator** — auto-create quizzes from uploaded materials
- **Flashcard System** — AI-powered flashcard creation and review
- **Smart Revision** — personalized revision schedules
- **PDF Summarizer** — extract key points from PDFs

### ⏱️ Study Mode (Students Only)
- **Study Timer** — Pomodoro-style timer with floating bubble indicator
- **Focus Mode** — activates Do-Not-Disturb (DND) on the device
- **Mood Selector** — track study mood for analytics
- **Weekly Reports** — study time analytics and progress visualization
- **Leaderboard** — gamified ranking among peers
- **Course Roadmap** — visual progress tracker per course

### 👥 Community
- **Community Board** — ask questions, share knowledge
- **Study Groups** — create/join study groups
- **Group Chat** — real-time messaging within groups
- **Study Battles** — gamified competitive study sessions

### 💳 Payments & Premium
- **Premium Screen** — subscription tiers and benefits
- **Subscription Screen** — manage active subscriptions
- **Paywall Gate** — restrict premium features for non-subscribers
- **Payment Verification** — Paymob payment confirmation flow

### 👤 Profile
- **Profile Screen** — view/edit personal info, profile picture, and settings
- **Edit Teaching Positions** — doctors select universities and faculties from **dropdown menus** (populated from a comprehensive Egyptian universities dataset with 50+ universities and their faculties)
- **CV Builder** — generate professional CVs
- **GPA Tracker** — calculate and track academic GPA
- **Student Portfolio** — showcase academic achievements

### 🛠️ Tools
- **Text-to-Voice** — convert text to speech using `flutter_tts`
- **OCR Scanner** — extract text from images using Google ML Kit
- **Exam Countdown** — countdown timers for upcoming exams
- **Task Manager** — personal task/to-do management

### 📶 Offline Mode
- **Offline Screen** — browse downloaded/cached content
- **Offline Manager** — Hive-based local storage for offline access

### 🎨 Onboarding
- **Onboarding Screen** — beautiful intro slides for first-time users

### 🔧 Admin
- **Doctor Approval Screen** — admin reviews and approves doctor registrations
- **Support Screen** — admin support management

---

## 🎨 Design & UX

- **Premium aesthetics** — carefully crafted light and dark themes with Material 3
- **Smooth transitions** — Cupertino-style page transitions throughout the entire app
- **Cross-fade navigation** — animated opacity transitions between bottom nav tabs
- **Splash screen** — elastic logo animation, sliding text, and pulsing loading dots via `flutter_animate`
- **RTL support** — full right-to-left layout for Arabic language
- **Cairo font** — consistent Arabic/English typography
- **Responsive** — adapts to all screen sizes

### 🎨 Figma Design

Explore the full design system and UI mockups on Figma:
[StudyHub Design on Figma](https://www.figma.com/design/ONy1RlE0a00yOiUb4UbcYr/Study-Hub?node-id=0-1&t=4BGLktOhigo3DjWC-1)

---

## 📂 Project Structure

```
lib/
├── main.dart                    # App entry point
├── firebase_options.dart        # Firebase configuration
├── offline_manager.dart         # Hive offline storage manager
├── generated/l10n/              # Auto-generated localization files
├── providers/
│   ├── app_provider.dart        # Theme, locale, global app state
│   ├── auth_provider.dart       # Firebase Auth + Firestore user data
│   └── study_provider.dart      # Study timer, sessions, stats
├── services/
│   └── focus_mode_service.dart  # DND / Focus Mode toggle
├── utils/
│   ├── app_theme.dart           # Light/Dark ThemeData
│   └── constants.dart           # Egyptian universities dataset, API keys
├── widgets/
│   ├── course_card.dart         # Reusable course card widget
│   ├── course_material_picker.dart
│   ├── focus_banner.dart        # Focus mode active banner
│   └── study_timer_bubble.dart  # Floating timer indicator
└── screens/
    ├── splash_screen.dart
    ├── admin/
    ├── ai/
    ├── auth/
    ├── courses/
    ├── home/
    ├── offline/
    ├── onboarding/
    ├── payment/
    ├── planner/
    ├── profile/
    ├── social/
    ├── study/
    └── tools/
```

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK ≥ 3.0.0
- Dart SDK ≥ 3.0.0
- Android Studio or VS Code
- Firebase project configured

### Installation

```bash
# Clone the repository
git clone https://github.com/your-username/studyhub.git
cd studyhub

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Configuration

1. Set up a Firebase project and add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS).
2. Configure Supabase credentials in `constants.dart`.
3. Set up Paymob API keys for payment integration.
4. Add your Google Gemini API key in `constants.dart`.

---

## 📊 Key Metrics

- **60+ Dart files** across 14 feature modules
- **50+ Egyptian universities** with complete faculty datasets
- **Bilingual** — Arabic & English with full RTL support
- **6+ AI-powered features** using Google Gemini
- **Zero-crash** file viewing and meeting architecture

---

## 👨‍💻 Developers

Built with ❤️ for Egyptian university students and educators.

---

## 📄 License

This project is proprietary. All rights reserved.

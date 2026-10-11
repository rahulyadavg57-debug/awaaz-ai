# 🎙️ Awaaz AI (आवाज़ क्लोन) - Hindi Voice Cloning & TTS Android App

A complete Android application built with **Flutter** that allows users to clone their own voice and generate natural **Hindi Text-to-Speech (TTS)** using AI.

---

## ✨ Features (मुख्य विशेषताएं)
* 🎤 **Voice Cloning (आवाज़ क्लोनिंग)**: Record 30-60 seconds of your voice sample directly from your phone microphone or upload an audio file to clone your unique voice.
* ✍️ **Hindi Text-to-Speech**: Type any text in Hindi (Devanagari or Roman Hindi) and convert it to speech in your cloned voice using the state-of-the-art `eleven_multilingual_v2` model.
* 🎛️ **Voice Tuning**: Customize Voice Stability and Clarity / Similarity sliders.
* 🔊 **Built-in Audio Player**: Listen to generated audio with a progress slider.
* 📤 **One-Tap Share & Save**: Share generated audio directly to WhatsApp, Telegram, or save to your phone storage.
* 📜 **History & Library**: Keep track of all previously generated audio clips.
* ☁️ **Automated Cloud APK Build**: Uses GitHub Actions to compile ready-to-install `.apk` directly in the cloud — no Android Studio required!

---

## 🚀 How to Build & Download APK via GitHub (GitHub से APK कैसे बनाएं और डाउनलोड करें)

Follow these simple 4 steps:

### 1️⃣ Step 1: Create a New Repository on GitHub
1. Open [github.com](https://github.com) in your browser and sign in.
2. Click the **"+"** button at the top right and select **"New repository"**.
3. Name your repository (e.g., `awaaz-ai-hindi`).
4. Set it to **Public** (or Private) and click **"Create repository"**.

---

### 2️⃣ Step 2: Push this Project to Your GitHub Repository
Open PowerShell or Terminal in this project folder (`C:\Users\MY PC\.gemini\antigravity\scratch\awaaz_ai`) and run:

```bash
git branch -M main
git remote add origin https://github.com/YOUR_GITHUB_USERNAME/awaaz-ai-hindi.git
git push -u origin main
```
*(Replace `YOUR_GITHUB_USERNAME` with your actual GitHub username).*

---

### 3️⃣ Step 3: Cloud Build Starts Automatically
1. Go to your GitHub repository page in your browser.
2. Click on the **"Actions"** tab at the top.
3. You will see **"Build & Release Android APK"** running (takes ~2 to 3 minutes).

---

### 4️⃣ Step 4: Download the APK File
1. Once the Actions build shows a green checkmark (✅), click on that workflow run.
2. Scroll down to the **"Artifacts"** section.
3. Click on **`Awaaz-AI-Release-APK`** to download the zip file.
4. Extract the zip file and transfer the **`app-release.apk`** to your Android phone to install!

---

## 🔑 How to Get a Free ElevenLabs API Key

1. Visit [elevenlabs.io](https://elevenlabs.io) and create a free account.
2. Click on your **Profile icon** at the bottom-left -> **API Keys**.
3. Click **"+ Create API Key"** and copy your key.
4. In the Awaaz AI app, go to **Settings (सेटिंग्स)** -> paste the API key -> click **Save Key**.

---

## 📱 Project Structure
```
awaaz_ai/
├── .github/
│   └── workflows/
│       └── build-apk.yml     # Automated cloud build workflow
├── android/                  # Android configuration & permissions
├── lib/
│   ├── models/
│   │   └── voice_model.dart  # Data models for voices and history
│   ├── services/
│   │   ├── elevenlabs_service.dart # Voice cloning & TTS API logic
│   │   └── storage_service.dart    # Preferences & file management
│   ├── screens/
│   │   ├── home_screen.dart      # TTS input, synthesis & audio player
│   │   ├── clone_screen.dart     # Voice recording & clone profile
│   │   ├── history_screen.dart   # Generated audio history
│   │   └── settings_screen.dart  # API key configuration
│   └── main.dart             # App entrypoint & bottom navigation
└── pubspec.yaml              # Dependencies
```

# Blink to Speak 👁️💬

**Empowering the non-verbal with the power of their eyes.**

Blink to Speak is an assistive communication application designed specifically for patients who are completely paralyzed or non-verbal (such as those with ALS, MND, Stroke, or severe Spinal Cord injuries). By using advanced AI-powered eye tracking, the app translates simple eye movements and blinks into clear, spoken messages.

---

## 🌟 The Mission
Communication is a fundamental human right. For many patients, the inability to speak leads to isolation and frustration. **Blink to Speak** aims to bridge this gap by providing a "voice" through eye gestures, allowing patients to express their needs, health concerns, and emotions independently.

## 🚀 Key Features

### 1. Real-time Interpretation 🧠
The core of the app. It uses the front-facing camera to track eye gestures in real-time. 
- **Gestures supported:** Blinks, Shuts, Winks (Left/Right), and Gaze directions (Up, Down, Left, Right).
- **Instant Translation:** Sequences of gestures are mapped to a library of messages.
- **Text-to-Speech (TTS):** Interpreted messages are spoken out loud instantly.

### 2. Interactive Practice Screen 🏋️‍♂️
A training ground for new users to master the eye-tracking interface.
- **Sequence Guides:** Shows the required eye movements for a specific phrase.
- **Visual Feedback:** A Diagnostic HUD (Heads-Up Display) shows the face mesh, eye landmarks, and pupil tracking in real-time.
- **Calibration Status:** Real-time feedback on whether the system is calibrated to the user's posture.

### 3. Caregiver Mode 👩‍⚕️
Allows family members and medical staff to customize the experience.
- **Personalized Messages:** Edit or add new message mappings to suit the patient's specific environment.
- **Language Support:** Full support for multiple languages including **English, Hindi, Kannada, Tamil, Marathi, and Telugu**.

### 4. Advanced Calibration Engine ⚙️
Designed for patients in bed, the app adaptively captures the user's "neutral" gaze and eye closure thresholds upon every start, ensuring high accuracy regardless of the patient's position or lighting.

---

## 🛠️ How It Works

Blink to Speak utilizes state-of-the-art computer vision to ensure reliability:
- **ML Kit Face Mesh:** Tracks 468 high-precision facial landmarks.
- **Eye Aspect Ratio (EAR):** Mathematically calculates the degree of eye closure to distinguish between natural blinks and intentional gestures.
- **Pupil Tracking:** A custom "darkest-pixel" algorithm gates the gaze tracking, freezing the coordinate system during blinks to prevent "pupil drift."
- **Temporal Smoothing:** Uses a rolling average of gaze coordinates to filter out micro-saccades and jitter.

---

## 📜 Communication Protocol Examples

The app follows a structured gesture language. For example:
- **`[ Blink ]`** → "Yes"
- **`[ Blink + Blink ]`** → "No"
- **`[ Blink + Left Gaze ]`** → "Call Guardian"
- **`[ Shut + Up Gaze ]`** → "Open the window"
- **`[ Wink Left + Right Gaze ]`** → "Call the nurse"

---

## 💻 Tech Stack
- **Framework:** [Flutter](https://flutter.dev/) (Cross-platform UI)
- **AI/ML:** [Google ML Kit Face Mesh Detection](https://developers.google.com/ml-kit/vision/face-mesh-detection)
- **State Management:** [Provider](https://pub.dev/packages/provider)
- **Storage:** [Shared Preferences](https://pub.dev/packages/shared_preferences) for local command persistence.

---

## 🏗️ Getting Started

### Prerequisites
- Flutter SDK (3.16.0+)
- Android Studio / VS Code
- A physical Android device (Camera required)

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/ThePerkyFellow/blink_to_speak.git
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```

---
<img width="2560" height="1440" alt="image" src="https://github.com/user-attachments/assets/7638f039-b1de-43ae-bcd3-5b466df98fa4" />



## ❤️ Acknowledgements
This project is inspired by the incredible work of the **Asha Ek Hope Foundation**. Their dedication to ALS patients and the creation of the [Blink to Speak Guidebook](https://ashaekhope.com/blink-to-speak/) laid the foundation for this digital implementation.

---
*Built with ❤️ for a better, more inclusive world.*

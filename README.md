# Local Opportunity Hub

**A Flutter-based mobile application for discovering employment and educational opportunities.**

## About the Project

Local Opportunity Hub is a mobile application developed using Flutter and Dart to help students, graduates and job seekers discover employment and educational opportunities in one convenient platform.

The application brings together job opportunities, internships, learnerships and bursaries. It allows users to create accounts, complete their profiles, search for opportunities, save opportunities and access external application websites.

The application also provides personalised recommendations based on the user's qualification and field of study, helping users identify opportunities relevant to their interests.

## Objectives

- Provide a centralised platform for employment and educational opportunities.
- Help students and graduates discover relevant opportunities.
- Recommend opportunities based on users' qualifications and fields of study.
- Allow users to save opportunities for later access.
- Help applicants keep track of application closing dates.
- Allow administrators to manage and publish opportunities.

## Features

### Applicant Features
- User registration and login.
- Password reset through email using Firebase Authentication.
- Applicant profile management.
- Personalised opportunity recommendations.
- Search and browse opportunities.
- View detailed opportunity information.
- Save and remove saved opportunities.
- Access saved opportunities offline using SQLite.
- In-app notifications with read and unread status.
- Firebase Cloud Messaging (FCM) push notification support.
- Public holiday calendar.

### Administrator Features
- Administrator login and role-based access.
- Add new opportunities.
- Edit existing opportunities.
- Manage published opportunities.
- Specify application closing dates.
- Publish opportunities to Firebase Cloud Firestore.

## Technologies Used

| Technology | Purpose |
|---|---|
| Flutter | Mobile application development |
| Dart | Programming language |
| Firebase Authentication | User registration, login and password reset |
| Cloud Firestore | Cloud database and opportunity management |
| Firebase Cloud Messaging | Push notification support |
| SQLite (sqflite) | Local storage of saved opportunities |
| Nager.Date REST API | South African public holiday information |
| Visual Studio Code | Development environment |

## Application Screens

The application includes the following screens:

- Registration and Login
- Complete Profile
- Home
- Search Opportunities
- Opportunity Details
- Saved Opportunities
- Notifications
- Applicant Profile
- Administrator Dashboard
- Add and Edit Opportunities
- Public Holiday Calendar

## Installation and Setup

### Requirements

- Flutter SDK
- Dart SDK
- Visual Studio Code or Android Studio
- Android emulator or Android smartphone
- Firebase project

### Steps to Run the Application

1. Clone the repository:

   ```bash
   git clone https://github.com/Nomusa03/local-opportunity-hub.git
   ```

2. Open the project folder:

   ```bash
   cd local-opportunity-hub
   ```

3. Install the project dependencies:

   ```bash
   flutter pub get
   ```

4. Configure Firebase for your own Firebase project if necessary.

5. Run the application:

   ```bash
   flutter run
   ```

### Build APK

To generate an Android release APK, run:

```bash
flutter build apk --release
```

The generated APK will be available at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Notifications

The application includes in-app notifications and Firebase Cloud Messaging support. FCM was tested using a device token and a test notification sent through the Firebase Console. In-app notifications also track read and unread status.

Automatic qualification-based push notifications triggered when an administrator publishes an opportunity are not yet implemented.

## Offline Functionality

SQLite is used to store saved opportunities locally. This allows applicants to access their saved opportunity information even when an internet connection is unavailable.

## Repository

GitHub: https://github.com/Nomusa03/local-opportunity-hub

## Developer

**Developed by:** Nomusa Mbokazi

**Qualification:** Diploma in ICT Application Development

**Project:** Local Opportunity Hub

## Licence

This project was developed for academic purposes.

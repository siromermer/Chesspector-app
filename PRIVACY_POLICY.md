# Chesspector — Privacy Policy

**Effective Date:** February 22, 2026  
**Developer:** siromer  
**Contact:** siromermer@gmail.com

---

## 1. Overview

Chesspector is a mobile application that allows users to photograph a physical chessboard, detect pieces using artificial intelligence, and analyze positions with the Stockfish chess engine. This privacy policy explains what data the app collects, how it is used, and how it is protected.

---

## 2. Data Collection

### 2.1 Images

When you use the board scanning feature, the app sends a photograph of the chessboard to our cloud servers (hosted on Amazon Web Services in the EU) for processing. The image is used solely to detect the chessboard corners and identify chess pieces. **Images are processed in real time and are not stored on our servers.** Once the analysis is complete, the image is discarded.

### 2.2 Device Identifiers

The app uses AWS Cognito Identity Pool to obtain temporary authentication credentials. This generates an anonymous device identifier (Cognito Identity ID) that is used exclusively for authenticating API requests. **No personal information is associated with this identifier.** We do not use it for tracking, advertising, or analytics.

### 2.3 Saved Games

Games you save within the app (PGN data, board positions) are stored **locally on your device only**. They are never transmitted to any server.

### 2.4 No Account Required

Chesspector does not require you to create an account, sign in, or provide any personal information such as your name, email address, or phone number.

---

## 3. Data We Do NOT Collect

- No personal information (name, email, phone, etc.)
- No location data
- No contacts or call logs
- No browsing history
- No advertising identifiers
- No analytics or usage tracking
- No cookies

---

## 4. Third-Party Services

The app uses the following third-party services:

| Service | Purpose | Data Sent |
|---|---|---|
| **Amazon Web Services (AWS)** | Image processing (corner detection, piece detection) | Chessboard photographs (not stored) |
| **AWS Cognito** | Anonymous authentication | Anonymous device identifier |

No data is shared with advertisers, data brokers, or any other third parties.

---

## 5. Data Security

- All communication between the app and our servers uses **HTTPS/TLS** encryption.
- API requests are authenticated using **AWS SigV4** signatures with temporary credentials.
- Server-side rate limiting is enforced to prevent abuse.
- Images are processed in memory and never written to persistent storage on our servers.

---

## 6. Children's Privacy

Chesspector does not knowingly collect any personal information from children under the age of 13. Since the app does not collect personal data from any user, it is suitable for all ages.

---

## 7. Changes to This Policy

We may update this privacy policy from time to time. Any changes will be reflected by updating the "Effective Date" at the top of this page. Continued use of the app after changes constitutes acceptance of the updated policy.

---

## 8. Contact

If you have any questions or concerns about this privacy policy, please contact:

**Email:** siromermer@gmail.com  
**GitHub:** https://github.com/siromermer

---

*This policy applies to the Chesspector Android application distributed via Google Play.*

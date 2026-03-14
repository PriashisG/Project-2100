# Project Title
**CP Trainer** – Competitive Programming Assistant App

# Description
This is a competitive programming helper app which integrates with Codeforces, AtCoder, and CodeChef accounts. It analyzes a user’s problem-solving history to identify strengths, weaknesses, and performance trends. The system functions as a personal competitive programming coach—providing contest reminders, recommending suitable problem ratings and topics for improvement, and generating daily custom contests tailored to the user’s skill level.

# Tools
### Frontend
- **Flutter** – to make the desktop/PC app
- **Dart** – programming language for Flutter
### Backend
- **FastAPI (Python)** – to create APIs and analyze user data
- **APScheduler** – to schedule tasks like daily contests and reminders
### Database
- **PostgreSQL** – to store user info, problem stats, and progress
### APIs & Data Sources
- **Codeforces API** – to get contest and problem data
- **AtCoder Problems API** – to get contest and problem data
- **CodeChef API** – to get contest and problem data

### Version Control & Deployment
- **GitHub** – for code backup, version control, and collaborative development
- **Deployment Options:**
    - **Standalone PC App** – package Flutter app for Windows/Linux/macOS
    - **Executable + Installer** – distribute as `.exe` (Windows) or `.dmg` (macOS)
    - **GitHub Releases** for version distribution and updates

## Additional Feature: User Activity Monitoring
The app monitors user submissions and contest participation to ensure active engagement. If any submission receives a “skipped” verdict, the system detects it and sends a warning notification to alert the user. This feature encourages consistent practice and helps prevent users from relying on AI tools or engaging in any form of plagiarism during contests.
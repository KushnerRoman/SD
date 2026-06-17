# Security Depot FSM
# System Architecture Draft v0.1

## Target Platforms

### Desktop
Primary platform for:
- Managers
- Service Coordinators

### Android
Primary platform for:
- Technicians

## Technology Stack

### Frontend

Flutter

Reasons:
- Single codebase
- Android support
- Desktop support
- Fast development

### Backend

Python FastAPI

Reasons:
- Fast API development
- Excellent future AI integration
- Strong ecosystem

### Database

PostgreSQL

Reasons:
- Reliable
- Scalable
- Relational data model

## Core Entities

### Site
Physical building/location

### Job
Customer request or project

### Visit
Technician attendance

### Technician
Field employee

### Part
Inventory item

### Attachment
Photos and files

## MVP Features

### Dashboard
Manager overview

### Jobs
Create and manage jobs

### Sites
Site history and information

### Visits
Technician updates

### Calendar Integration
Google Calendar synchronization

### Map View
Job and site locations

## Future Features

- Outlook Integration
- Slack Integration
- AI Email Parsing
- AI Job Classification
- Inventory Management
- Customer Portal
- GPS Tracking
- Route Optimization

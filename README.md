# Vikunja iOS Client

**This is not an official Vikunja Client app**

## Description

This is a native iOS client for Vikunja with beautiful design and great user experience.

## How to Use

### Installation

You can find this app in the App Store

### Setup

1. Create an API Token in Vikunja. See the [required scopes](#required-permissions)
2. Connect to your Vikunja Instance in the app using the token
3. **Optional:** Setup the Companion Service for better UX

## Features

- Support for multiple Vikunja instances
- Quick Capture (Pending)
- Widgets
- Siri Shortcuts
- Daily Briefing*
- AI Suggestions and Analysis (Opt-In, **NOT FORCED!!**)*

*Features marked with \* require the [Companion Service](#companion-service)*

### Vikunja Supported Feature Matrix


- Tasks
    - Create Task
    - Delete Task
    - Update Task
    - Move task to another project
- Projects
    - Create project
    - Delete project
    - Update project
- Comments
    - Add comment to task
    - Update comment 
    - Delete comment
- Attachments
    - Add attachments to tasks 
- Task Relations
    - Add relations between tasks
    - Remove relations between tasks
- Labels
    - Create labels
    - Delete labels
    - Assign/Unassign Labels to tasks

## Companion Service

This app works perfectly fine by pointing it to your Vikunja Instance. Nothing else needed. However we provide a light companion self-hosted service
that adds a set of nice features

### Features you get from the Companion Service

- Native Push notifications (by relying on Vikunja webhooks)
    - Daily digest, instead of 15 push notifications you get 1 summary notification
- Performance improvements (better query support and caching)

### Setup

Run with docker...

Point the app to the new service (tip: create a new connection for this so you can go back to your current setup if needed)


## Required Permissions

This app requires an API Token with the following permissions to work:



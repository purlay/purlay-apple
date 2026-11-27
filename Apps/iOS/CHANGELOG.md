# Changelog

Changes a person notices in Purlay for iPhone and iPad. Requires iOS 18 or later. A version's section is written as its changes
land, headed "Unreleased" until it ships (`scripts/ci/changelog-versions` requires a section for the version
`Config/iOS.xcconfig` states).

## [0.1.0] — Unreleased

- Sign in through your browser, on the server's own page: the app never asks for your password, and keeps you signed in.
- English and Turkish for every sentence; the problem screens say what is wrong in words for a person and offer Try Again.
- A launch screen of the Purlay mark, which stays in place while the app connects and becomes the Welcome screen.
- Sign out on this device or everywhere from the Account menu. An offline sign-out explains that the server was not notified.
- Send text messages from the native channel feed and retry a failed send in place.
- Open joined channels from Chat and read their native message history. Load earlier messages without leaving the feed.
- Switch between workspaces from the signed-in app. Available destinations appear in iPhone tabs and the iPad sidebar.
- The app's icon is the Purlay mark.
- The sign-in and loading screens scroll at the largest text sizes.
- Turkish speaks to you formally ("siz"), as the web does, and two-step verification has the web's name in both languages.
- A server's update requirement for iPhone and iPad is the one the app follows; the Mac's no longer applies to it.

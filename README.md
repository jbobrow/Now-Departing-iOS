# 🚇 Now Departing - iOS & watchOS
Know when your train is coming. That's it. Live NYC Subway times for the stations around you and the trains you ride most, on iPhone, Apple Watch, widgets and the Lock Screen.

[![Now Departing](https://nowdeparting.app/img/og-image.png)](https://nowdeparting.app)

[Download on the App Store](https://apps.apple.com/app/id6740440448) · [nowdeparting.app](https://nowdeparting.app)

## Description
- **Nearby**: live countdowns for every train near you, with the walk to each station
- **Lines**: every station on a line, closest first. Press and hold a line to peek at its nearest station and next trains
- **Favorites**: swipe right on a train to save it, then keep an eye on it from a Home Screen widget, a Live Activity, or your wrist
- **Service changes**: MTA alerts show right next to the trains they affect
- Arrival times come straight from the MTA's real-time GTFS feeds, and station hours are refreshed from the MTA schedule automatically

## In this repo
- `Now Departing/`: the iPhone app
- `Now Departing Watch Watch app/`: the Apple Watch app and complications
- `NowDepartingWidget/`: Home Screen and Lock Screen widgets, and the Live Activity
- `Shared/`: the feed parsing, stations and models all three share, including `stations.json` (which installed apps fetch live, so keep it backward compatible)
- `scripts/`: Python tools for generating and validating station data from the MTA's GTFS
- `NowDepartingAndroid/`: an Android and Wear OS version, in progress

## Gratitude
With the encouragement of a friend in Brooklyn as well as early beta testers and commenters on Twitter, I felt inspired to make this tiny, convenient app native. The [first iteration](https://github.com/jbobrow/MTA-Subway-Now-Departing/tree/main) of this began as a widget for my iPhone, made possible by the incredible App/tool [Scriptable](https://scriptable.app/). Scriptable is by far the quickest way I've ever designed and developed an app for the iPhone and the very first widget I ever made. The MTA does a nice job of making the Subway times available via an API, and early on @jonthornton's [MTAPI](https://github.com/jonthornton/MTAPI?tab=readme-ov-file) made it even nicer by converting it to an easier JSON format, which is how this all got off the ground. In addition to the many indie developers that inspire me to make something elegant, useful, fun, beautiful... every day, -perhaps I should place a nice list here- I am grateful for my partner who gifted me the Apple Watch for the holidays, giving me an incredibly selfish reason to make this project real. And thank you to everyone who has used it, written in, and told a friend on the platform.

## Development notes
The first version was co-developed w/ ChatGPT. While it wasn't the first time I'd worked in Xcode or with Apple technology, it was the first time I'd made a watchOS app, used SwiftUI, or really any of the simple, yet still neat things this app does. [Here](https://chatgpt.com/share/6779f476-95ac-8012-8db2-d53c35c28703) is what that conversation looks like, picking up from my very first one that helped me start with a simple grid of icons based on my Figma mockup.

Since then, it's grown up alongside [Claude Code](https://claude.com/claude-code), which helped bring widgets, Live Activities, service alerts, the walkthrough, and a lot of careful station data cleanup to life.

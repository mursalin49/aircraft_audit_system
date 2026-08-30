# Flight Card Status Indicator

## Purpose

This document explains the small colored status dot shown at the top-right of each flight card in the mobile app.

File reference:
- `lib/widgets/flight_card.dart`
- `lib/config/aviationstack_config.dart`

## Current UI Behavior

The flight card header shows:
- airline name
- flight number badge
- movement badge
  - arrival icon
  - departure icon
- status dot

The status dot is rendered by:
- `FlightCard._buildStatusBadge()`

## Is There A Visible Legend In The UI?

No.

At the moment, there is no legend or key at the top of the screen that explains what the colored dot means.

## Status Dot Color Mapping

The status dot color is determined from `flight.status`.

### Green Dot

Config color:

```text
AviationStackConfig.statusActive = Color(0xFF22C55E)
```

The app currently shows the green dot for these statuses:
- `active`
- `scheduled`
- `approaching`
- `landed`
- `on-ground`
- `departed`

Meaning:
- the flight is treated as operational / normal / active-state in the UI

Important note:
- green does not mean only one exact flight state
- several different statuses are grouped into the same green indicator

### Yellow Dot

Config color:

```text
AviationStackConfig.statusDelayed = Color(0xFFEAB308)
```

The app shows the yellow dot for:
- `delayed`

Meaning:
- the flight is delayed

### Red Dot

Config color:

```text
AviationStackConfig.statusCancelled = Color(0xFFEF4444)
```

The app shows the red dot for:
- `cancelled`

Meaning:
- the flight is cancelled

### Gray / Slate Dot

Config color:

```text
AviationStackConfig.statusUnknown = Color(0xFF64748B)
```

The app shows the gray dot for:
- any unrecognized status
- missing or unknown status values

Meaning:
- the app could not match the status to one of the known UI categories

## Current Mapping Logic

This is the current behavior in `flight_card.dart`:

```text
Green  -> active, scheduled, approaching, landed, on-ground, departed
Yellow -> delayed
Red    -> cancelled
Gray   -> unknown / fallback
```

## UX Note

Because multiple statuses are grouped into the green dot, users may assume green means only "active" or "on time" when it actually includes:
- scheduled
- approaching
- landed
- on-ground
- departed

If clearer UX is needed, one of these improvements can be added later:
- add a small legend above the flight list
- show a text status chip next to the dot
- split green into more specific status colors

## Suggested Legend Copy

If a legend is added to the UI, this is a good short version:

```text
Green = Active / Normal
Yellow = Delayed
Red = Cancelled
Gray = Unknown
```

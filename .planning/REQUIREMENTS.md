# Requirements: Mr. Funny Jokes

**Defined:** 2026-02-20
**Core Value:** Users can instantly get a laugh from character-delivered jokes and share them with friends

## v1.1.0 Requirements (Save & Me Tab Rework)

Requirements for extending v1.1.0 before App Store submission. Decouples rating from saving and redesigns the Me tab.

### Save System

- [ ] **SAVE-01**: User can save a joke from the joke detail sheet via a Save button (person icon)
- [ ] **SAVE-02**: Save button appears below rating section and above Copy/Share in joke sheet
- [ ] **SAVE-03**: Saved state persists across app sessions via UserDefaults
- [ ] **SAVE-04**: Save button toggles between "Save" and "Saved" states — tap to save, tap again to unsave
- [ ] **SAVE-05**: Saving a joke is independent of rating — user can save without rating

### Rating Decoupling

- [ ] **RATE-01**: Rating a joke no longer adds it to the Me tab
- [ ] **RATE-02**: Rating icon remains on joke card, opening sheet shows user's rating
- [ ] **RATE-03**: Ratings still persist to UserDefaults and Firestore for All-Time Top 10

### Data Migration

- [ ] **MIGR-01**: All previously rated jokes are automatically converted to saved jokes on first launch

### Me Tab Redesign

- [ ] **METB-01**: Me tab shows saved jokes (not rated jokes)
- [ ] **METB-02**: Saved jokes ordered by date saved, newest first
- [ ] **METB-03**: Each saved joke row shows Hilarious/Horrible indicator if user rated it
- [ ] **METB-04**: Segmented control (Hilarious/Horrible) removed from Me tab

## Out of Scope

| Feature | Reason |
|---------|--------|
| Swipe-to-delete saved jokes | Save/Saved toggle handles removal |
| Cloud sync of saved jokes | UserDefaults sufficient for device-local, no auth system |
| Save from joke card (without opening sheet) | Keep card interaction simple, save lives in sheet |
| Save collections/folders | Over-engineering for a joke app |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SAVE-01 | — | Pending |
| SAVE-02 | — | Pending |
| SAVE-03 | — | Pending |
| SAVE-04 | — | Pending |
| SAVE-05 | — | Pending |
| RATE-01 | — | Pending |
| RATE-02 | — | Pending |
| RATE-03 | — | Pending |
| MIGR-01 | — | Pending |
| METB-01 | — | Pending |
| METB-02 | — | Pending |
| METB-03 | — | Pending |
| METB-04 | — | Pending |

**Coverage:**
- v1.1.0 requirements: 13 total
- Mapped to phases: 0
- Unmapped: 13 ⚠️

---
*Requirements defined: 2026-02-20*
*Last updated: 2026-02-20 after initial definition*

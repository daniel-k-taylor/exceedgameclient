# Card & Character Art Sources

Card art is **not** stored in this repo. Decks reference remote images via the
`image_resources` block in `data/decks/<id>.json`, which the client downloads and caches
(`globals/card_image_loader.gd`, `ImageCache`).

This file records where the art for recently-added characters came from, so the links are
easy to re-derive if an image ever needs re-hosting.

## `image_resources` shape

```json
"image_resources": {
    "character_default":  { "url": "https://i.imgur.com/....jpeg", "multiple_cards": false },
    "character_exceeded": { "url": "https://i.imgur.com/....jpeg", "multiple_cards": false },
    "cardback":           { "url": "https://i.imgur.com/....jpeg", "multiple_cards": false },
    "specials":           { "url": "https://i.imgur.com/....jpeg", "multiple_cards": true  },
    "normals":            { "url": "https://i.imgur.com/....jpeg", "multiple_cards": true  }
}
```

`multiple_cards: true` marks a **sprite sheet**; individual cards index into it with
`image_name` + `image_index` on each entry in the deck's `cards` array.

## Source albums

| Album | Contents |
| --- | --- |
| <https://imgur.com/a/3mwGlqK> | Season 2 — Seventh Cross, Automata, Red Dragon Inn, Shovel Knight |
| <https://imgur.com/a/qINzYqk> | "S1 Remaster: Take Two" — Season 1 / Red Horizon |

The album web pages are JavaScript-rendered, so scraping the HTML returns nothing useful.
Use the JSON API instead:

```
https://api.imgur.com/post/v1/albums/<album_id>?client_id=546c25a59c58ad7&include=media
```

The `qINzYqk` album was validated as the correct Season 1 source: its normals sheet and its
nehtali / superskullman / morathi specials hashes are byte-identical to URLs already used by
our pre-existing Season 1 decks.

## Shared sheets

These are referenced by many decks — do not duplicate or re-upload them.

| Resource | URL | Used by |
| --- | --- | --- |
| Card back (all decks) | <https://i.imgur.com/s6wpKBq.jpeg> | 39 decks |
| Street Fighter normals | <https://i.imgur.com/tXuqP40.jpeg> | 12 decks (ryu, ken, akuma, ...) |
| Season 1 normals | <https://i.imgur.com/PFHTq9B.jpeg> | 6 decks (meilian, morathi, nehtali, superskullman, ulrik, vincent) |
| Season 2 normals | <https://i.imgur.com/1pnJnEb.jpeg> | 18 decks |

## Per-character sources

All URLs below were fetched and confirmed to return a valid image.

### Season 1 (Red Horizon) — album `qINzYqk`

| Character | Resource | URL |
| --- | --- | --- |
| Ulrik (`ulrik`) | character_default | <https://i.imgur.com/SHxCBg5.jpeg> |
| | character_exceeded | <https://i.imgur.com/Cw8fInX.jpeg> |
| | specials | <https://i.imgur.com/2IDXwgA.jpeg> |
| | normals | S1 normals (shared) |
| Mei Lien (`meilian`) | character_default | <https://i.imgur.com/k10cQcW.jpeg> |
| | character_exceeded | <https://i.imgur.com/Vdg324i.jpeg> |
| | specials | <https://i.imgur.com/ij6Tz5n.jpeg> |
| | normals | S1 normals (shared) |

> The official spelling is **Mei Lien**. The deck id stays `meilian` because it must match the
> `meilian_*` card `definition_id` prefix.

### Season 2 — album `3mwGlqK`

| Character | Resource | URL |
| --- | --- | --- |
| Luciya (`luciya`) | character_default | <https://i.imgur.com/oZxg8jB.jpeg> |
| | character_exceeded | <https://i.imgur.com/Fl5BOU0.jpeg> |
| | specials | <https://i.imgur.com/NBCBBtl.jpeg> |
| Minato (`minato`) | character_default | <https://i.imgur.com/1aaPuUA.jpeg> |
| | character_exceeded | <https://i.imgur.com/ZkxbFko.jpeg> |
| | specials | <https://i.imgur.com/HjyWn47.jpeg> |
| Tournelouse (`tournelouse`) | character_default | <https://i.imgur.com/cqBoFa6.jpeg> |
| | character_exceeded | <https://i.imgur.com/pX2fSSA.jpeg> |
| | specials | <https://i.imgur.com/x88VcfA.jpeg> |
| Pooky (`pooky`) | character_default | <https://i.imgur.com/k10oJQj.jpeg> |
| | character_exceeded | <https://i.imgur.com/lUJU2bE.jpeg> |
| | specials **and** normals | <https://i.imgur.com/WCBeoio.jpeg> |
| Syrus (`syrus`) | character_default | <https://i.imgur.com/dBlUanM.jpeg> |
| | character_exceeded | <https://i.imgur.com/v9ktYxx.jpeg> |
| | specials | <https://i.imgur.com/WOFFNc9.jpeg> |
| Renea (`renea`) | character_default | <https://i.imgur.com/MQEQXEo.jpeg> |
| | character_exceeded | <https://i.imgur.com/XhyBxSn.jpeg> |
| | specials | <https://i.imgur.com/fE0tYUI.jpeg> |
| | briefcase (buddy) | <https://i.imgur.com/tXxcPcU.jpeg> |
| Umina (`umina`) | character_default | <https://i.imgur.com/d9OB4J2.jpeg> |
| | character_exceeded | <https://i.imgur.com/mLakrZ0.jpeg> |
| | specials | <https://i.imgur.com/ORCMPBO.jpeg> |
| | Dreamlands (buddy) | <https://i.imgur.com/QuWqooi.jpeg> |
| | Dreamlands exceeded | <https://i.imgur.com/an7eDIa.jpeg> |

All Season 2 characters above use the shared Season 2 normals sheet, except Pooky.

## Known caveats

- **Pooky** uses a single combined sheet for both `normals` and `specials`, unlike every other
  deck. The `image_index` values for its normals are therefore offset into the same sheet.
- **Renea's briefcase** uses the same image for `briefcase` and `briefcase_exceeded`. A distinct
  exceeded-side image was not located in the album; worth re-checking if one exists.
- Imgur rate-limits aggressively (HTTP 429) when many images are requested in quick succession.
  Add a delay when bulk-verifying links.

## Not yet ported

The `qINzYqk` album also contains art for roughly a dozen additional official Season 1
characters that this client does not ship yet. If those characters are added later, their art
is available from that album.

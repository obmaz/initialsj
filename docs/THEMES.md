# Fifteen distinct route themes

All 15 nodes use different theme IDs, scenery, roadside art and destination titles. Every full tour visits five different themes. Left and right choices still determine the same cumulative road difficulty as before.

| Stage | Destinations, left to right |
| --- | --- |
| 1 | Hawaii |
| 2 | Desert · City |
| 3 | Pyramids · Amusement park · Jeju |
| 4 | Ruined city · Seoul · Fuji lakeside · Neon district |
| 5 | Red canyon · Container port · Bamboo pass · Snow pass · Volcanic coast |

The native visual review covers all themes via `tests/preview_tour.gd`. New screenshots are `tour/fuji.png`, `tour/neon.png`, `tour/canyon.png`, `tour/harbor.png`, `tour/bamboo.png`, `tour/snow.png` and `tour/volcano.png`. These are controlled rendered fixtures, not photographs of real places.

## Generated roadside objects

`assets/environment/route-props.png` is one generated 4×4 transparent sprite atlas. Fifteen cells hold themed prop clusters; the last cell is empty. The first generation had unwanted pale backgrounds, so a second image-generation edit removed those backgrounds. The final PNG is copied unchanged into the project; both original generated outputs are preserved in the workspace.

`route_prop_catalog.gd` records tight alpha bounds for each cell. The game samples those UV regions directly; separate edited/cropped image files are not needed. The texture uses mipmaps, lossless import and alpha cutoff. Transparent padding does not appear as white rectangles in the game.

`roadside_art.gd` batches upright camera-facing planes and ground shadows in the actual 3D world. Different distances, scales, staggered positions and occasional mirrored UVs produce roadside parallax. Conservative clearance keeps the painted silhouettes outside the pavement and guardrails. Early fork props are confined to the outside edge so the other branch stays clear. Terrain has subdivisions across its width to match prop placement more closely.

Main art subjects: palms and hibiscus; cactus and sandstone; retail facades; Egyptian obelisks and guardian; carnival kiosk; dol hareubang and basalt; ruined facade and abandoned bus; hanok and ginkgo; cherry tree and stone lantern; neon storefront; sandstone butte; container crane; bamboo; snowy pine and ice; basalt with lava cracks.

Roads, cars, rails, tunnels and large terrain remain 3D. Three-dimensional city silhouettes, the Seoul tower, Ferris wheel, Jeju wind turbines and pyramids supplement the image props. A three-dimensional Fuji peak and volcanic cone provide distant mass; snow now uses generated irregular ridges instead of repeated plain cones. The neon district has night lighting and headlamps; snow, canyon, harbor, bamboo and volcano use their own sky/fog palettes. Theme transitions blend lighting over three seconds.

## Checks

`tests/race_test.gd` checks 15 globally unique themes, different siblings at every fork, and no repeats across all 16 complete paths. It also checks atlas coverage, meaningful alpha transparency in every used cell, actual instantiated image props, and clearance from the playable road. Existing geometry, nitro, timer, contact and difficulty checks continue to run. `tests/tour_review.gd` confirms that the same left/right/mixed drivers still finish with the same timings after the scenery changes.

## Distant terrain pass — 2026-11-06

`horizon-ridges.png` is a new transparent generated 2×2 atlas: Hawaiian volcanic folds, Jeju headland, desert mesas and alpine peaks. The generated original was copied unchanged; tight alpha bounds are sampled by UV, with lossless texture import and mipmaps. Six Tour themes select their appropriate cutout. Up to four distant world-space placements are batched per section, with deterministic scale/position and conservative road clearance. They move with perspective as the road turns. Hidden sibling ground also hides its distant ridge batch. TRACK keeps its restored Fuji panorama.

Hawaii and Jeju have low three-dimensional inland hills with a tapered outer edge and darker green terrain. Coastal fallback ground uses a water color so a green strip no longer surrounds the ocean. Water uses non-perpendicular swells, a world-space normal and a restrained grazing-angle sheen, replacing the old high-contrast sine/cosine checkerboard.

Native captures for Hawaii, Jeju, desert and snow were compared during the pass. An initial hill shape was too tall and broad; its height and extent were reduced. Snow's repeated geometric cones were removed after comparison with the generated peaks. Existing gameplay, mode and road-surface checks pass; the changes do not alter road geometry or driving rules.

## Urban skyline and lighting pass

`urban-skylines.png` is a second untouched generated atlas for modern city, Seoul-inspired architecture, abandoned city and neon skyline. A generative edit removed two detached artifacts and improved cell padding; both generated originals remain in the workspace. UV regions sample the clean atlas directly with alpha scissor and mipmaps. The skyline batch supplements the existing six three-dimensional building shapes, rooftop details and near-road props.

Urban ground uses paving instead of grass, with derivative-filtered joints to limit distant shimmer. Street lamps add three-dimensional poles and fixtures; neon lamps and longer Tour tunnels use actual nearby point lights. Night facade windows vary in warm/cool color and occupancy. Fill lighting is excluded from procedural-sky sun rendering. Reviewed captures for city, Seoul, ruins, neon and a long tunnel show the current HUD and fictional vehicle badge.

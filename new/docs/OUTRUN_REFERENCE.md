# OutRun 2006 reference

Original public material consulted:

- [SEGA instruction manual, mirrored at Old Games Download](https://oldgamesdownload.com/manual/outrun-2006-coast-2-coast-windows-manual-english/): OutRun mode, checkpoint time extensions, route forks and brake/steer/accelerator drifting.
- [GameSpot review](https://www.gamespot.com/reviews/outrun-2006-coast-2-coast-review/1900-6148519/): accessible high-speed arcade driving, drift handling and varied destinations.
- [GameSpot hands-on](https://www.gamespot.com/articles/outrun-2006-coast-2-coast-hands-on/1100-6147417/): driving modes and arcade presentation.
- Public screenshots were used for visual inspection of the chase camera, large countdown, branching roads and sustained sideways cornering. Original game images, cars, audio and map geometry are not distributed in this project.

Applied here: five-stage open-road time attack, a triangular 15-node route graph, four physical left/right junctions, checkpoint time bonuses, momentum-preserving brake-tap drifting, traffic and slipstream. These are original simplified implementations, not a handling-accurate recreation. Eight requested themes have their own geometry and palette. GAS and BRAKE replace the earlier automatic acceleration and nitro control. Space/DRIFT remains an accessible drift shortcut.

The source reference emphasizes maintaining a slide through a bend. Here a drift latches after initiation, accepts steering corrections and ends when the player straightens the car, brakes firmly or loses sufficient speed. Tight corners exceed normal grip, so holding gas and ignoring steering fails the tour.

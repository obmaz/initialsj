# Coast Rush loading screen

The first page paint shows original generated key art featuring the white Nimori hatch, orange Veltrix wedge, blue striped Ironvale fastback and sunset coastal road. The image contains the Initial SJ / Coast Rush title. It is splash illustration, not an in-game screenshot.

- `assets/ui/coast-rush-splash.png`: generated artwork copied without visual edits. The original is preserved in the workspace's `generated_images/exec-e2fb208d-2c7a-41cc-a8d8-192e3f1b84bb.png`.
- `project.godot`: uses the same artwork for the engine boot splash and a custom chevron icon for exported browser icons.
- `web/coast-rush-shell.html`: custom web export shell based on Godot's MIT-licensed template. The artwork appears before engine JS downloads. A real download progress bar changes to “Preparing your ride” when downloads finish, and the overlay is removed when startup succeeds. The image uses `object-fit: contain` to keep the title and cars visible at different aspect ratios.
- Failed engine initialization retains a readable notice. A listener limited to startup also handles an exhausted WASM download rejection that can escape the runtime's `startGame` promise; it is removed after successful startup or failure.
- Reduced-motion preference disables the indeterminate progress animation. Status/progress labels and a screen-reader title are provided.

After exporting the game, run:

```sh
node new/tests/loading_review.cjs
```

The test delays real JS/data requests to verify artwork before engine loading, checks desktop/phone landscape/portrait layouts, checks reduced motion and actual progress, lets the game reach its garage, and aborts the WASM download to verify the failure notice. Set `INITIALSJ_REVIEW_URL` for a deployed build and `INITIALSJ_LOADING_OUTPUT` to keep remote-review screenshots outside the source tree.

![Branded loading screen](loading/progress.png)

Only `new/` is changed. Existing engine/audio license notices remain in the project.

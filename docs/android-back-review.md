# Android/browser Back

The Web shell retains one same-URL history guard. Browser Back returns to the
guard's base entry, immediately rearms it, and calls the game's back action.
Rearming replaces the forward guard, so repeated Back does not grow the stack.
The root menu releases the guard and permits normal navigation away from the game.
Install help closes before a screen navigation action.

| Current screen | Back action |
| --- | --- |
| Racing or countdown | Pause and release held touch controls |
| Pause dialog | Resume the preserved race/countdown |
| Track vehicle selection | Circuit selection |
| Tour vehicle selection | Main menu |
| Circuit selection | Main menu |
| Settings | Screen that opened settings |
| Results | Vehicle selection |
| Transition in progress | Consume the event without queuing another action |
| Main menu | Normal browser exit |

The game retains its JavaScript callback until scene cleanup. State changes
update the guard's enabled state immediately, without frame polling. Native
Android's back notification uses the same handler and disables automatic quit
while an internal screen can handle Back.

Validation: `node tests/back_bridge_review.cjs` exercises the actual shell code
with a history/DOM model: 30 repeated Back events retain one guard, preserve
unrelated state and the URL, close install help first, and release normal exit.
`tests/back_navigation_checks.gd` checks all screen actions, race progress/input
preservation, native/JavaScript entry points, and rapid Back during transitions
under Godot 4.7.2. Both pass. These are automated bridge/state checks; Android
Chrome hardware-button timing still needs confirmation on the user's device.

독립 재리뷰에서 BFCache로 복원되는 브라우저 Forward가 다시 이전 사이트로 밀려나는 경계조건을 찾아 수정했습니다. guard에서 나온 Back과 바깥에서 들어온 Forward를 구분하고, Forward는 게임 액션 없이 재진입시킵니다. 같은 모의 history 검사에 이탈→Forward→다시 Back 회귀를 포함했습니다.

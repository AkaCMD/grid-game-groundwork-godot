# QUACK!!! on ICE — 3D example

Open `examples/quack.tscn` and press F6, or open `examples/levels/quack.tres` in Grid Levels and click Playtest. The example uses the existing authoring palette, painting, selection, movement, saving and isolated playtest workflow.

Click a duck to select it. Its cube background turns black; other cubes have white backgrounds. WASD/arrows always mean −Z/+Z/−X/+X, independent of camera rotation; labels around the board show those directions. Middle drag orbits, Shift+middle drag pans, wheel zooms, and F frames. Z/Y/R undo, redo and restart. Selection is not a history action, and clicks during animation are ignored so buffered moves cannot switch actors unexpectedly.

Each hungry duck slides until blocked or eating one bread. Ducks block each other without pushing. Eating stops the slide immediately; fed ducks still slide, but cannot pass or eat another bread. Unsupported ducks fall, then continue in the original direction on landing. Bread interactions are checked after every grid displacement: eating during a fall finishes gravity but ends horizontal sliding, and bread can support a fed duck without being consumed. Falling out fails. All three bread consumed wins. One undo restores a whole slide, including all falls, feeding, bread removal and outcome. Restart is also undoable.

## Verified walkthrough

Coordinates are `(X, Y, Z)`; Y is height. A starts on the upper platform at `(-1, 2, 1)`, B at `(0, 0, 3)`, and C at `(0, 0, 0)`. Click the indicated duck before each change of actor.

| Step | Duck | Key | Endpoint | Effect |
| --- | --- | --- | --- | --- |
| 1 | A | D | `(3, 0, 1)` | Drops at `(0, 0, 1)`, continues sliding and eats bread A. |
| 2 | A | A | `(0, 0, 1)` | Fed A moves back to the west wall. |
| 3 | B | D | `(2, 0, 3)` | B eats bread B. |
| 4 | C | D | `(3, 0, 0)` | C slides to the east wall. |
| 5 | A | W | `(0, 0, 0)` | Fed A moves again, becoming C's stopper. |
| 6 | C | A | `(1, 0, 0)` | C stops against A, aligned with the narrow bread lane. |
| 7 | C | S | `(1, 0, 2)` | C eats the final bread; all ducks are fed. |

The lower board's internal walls at `(0, 0, 2)`, `(2, 0, 2)` and `(3, 0, 2)` constrain access to the final bread. The upper duck must descend to reach any bread, because every bread is on the lower board and ducks cannot climb. The simulation test exhausts reachable states twice: no solution exists if fed ducks cannot move, or if actions ending against another duck are disallowed. It also verifies the walkthrough, full-action history, failure recovery, visual feeding/selection, and native save/reload.

## Assets and rebuilding

Original sprites are pinned to [AkaCMD/Bevy_Jam_4 commit 1b017d7](https://github.com/AkaCMD/Bevy_Jam_4/tree/1b017d7a87e4a9828c3bd5a955f01f5872ea36a6), under that project's MIT license; see `examples/assets/quack/LICENSE-MIT` and the third-party notices. A nearest-filtered shader composites each sprite's transparent pixels over the cube's background; all six faces use the whole sprite. Editor and runtime instantiate the same visual scene, including fed-state restoration.

Regenerate only this example with `godot --headless --path . --script tools/create_quack.gd`. This replaces QUACK's definitions and level; it leaves Sokoban and pipes untouched. The formal scope is [issue #4](https://github.com/AkaCMD/grid-game-groundwork-godot/issues/4).

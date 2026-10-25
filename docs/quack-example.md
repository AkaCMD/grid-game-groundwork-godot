# QUACK!!! on ICE: 3D example

**English** | [简体中文](quack-example.zh-CN.md) · [README](../README.md) · [Designer guide](designer-guide.md)

Feed the three ducks by sliding them to bread and using fed ducks as stoppers. Open [examples/quack.tscn](../examples/quack.tscn) and choose **Run Current Scene**, or open [examples/levels/quack.tres](../examples/levels/quack.tres) in Grid Levels and click **Playtest**. Editing follows the [designer guide](designer-guide.md).

Click a duck to select it. Its cube background turns black; other cubes have white backgrounds. WASD/arrows always mean −Z/+Z/−X/+X, independent of camera rotation; labels around the board show those directions. Middle drag orbits, Shift+middle drag pans, wheel zooms, and F frames. Z/Y/R undo, redo and restart. Selection is not a history action, and clicks during animation are ignored so buffered moves cannot switch actors unexpectedly.

Each hungry duck slides until blocked or eating one bread. Ducks block each other without pushing. Eating stops the slide immediately; fed ducks still slide, but cannot pass or eat another bread. Unsupported ducks fall, then continue in the original direction on landing. Bread interactions are checked after every grid displacement: eating during a fall finishes gravity but ends horizontal sliding, and bread can support a fed duck without being consumed. Falling out fails. All three bread consumed wins. One undo restores a whole slide, including all falls, feeding, bread removal and outcome. Restart is also undoable.

## Verified walkthrough

The walkthrough applies to the supplied, unedited example level and is checked by [tests/test_quack.gd](../tests/test_quack.gd). Coordinates are `(X, Y, Z)`; Y is height. A starts on the upper platform at `(-1, 2, 1)`, B at `(0, 0, 3)`, and C at `(0, 0, 0)`. Click the indicated duck before each change of actor.

| Step | Duck | Key | Endpoint | Effect |
| --- | --- | --- | --- | --- |
| 1 | A | D | `(3, 0, 1)` | Drops at `(0, 0, 1)`, continues sliding and eats bread A. |
| 2 | A | A | `(0, 0, 1)` | Fed A moves back to the west wall. |
| 3 | B | D | `(2, 0, 3)` | B eats bread B. |
| 4 | C | D | `(3, 0, 0)` | C slides to the east wall. |
| 5 | A | W | `(0, 0, 0)` | Fed A moves again, becoming C's stopper. |
| 6 | C | A | `(1, 0, 0)` | C stops against A, aligned with the narrow bread lane. |
| 7 | C | S | `(1, 0, 2)` | C eats the final bread; all ducks are fed. |

Steps 5 and 6 use fed A to stop C at the final bread lane. Fed ducks remain movable.

## Assets and rebuilding

Sprite provenance and the MIT license are in the [third-party notices](../THIRD_PARTY_NOTICES.md#quack-on-ice-sprites). The [QUACK rule](../examples/rules/quack_rule.gd) implements the mechanics; [quack_visual.gd](../examples/visuals/quack_visual.gd) implements the appearance. To rebuild the level and definitions, follow [example regeneration](development.md#regenerate-examples).

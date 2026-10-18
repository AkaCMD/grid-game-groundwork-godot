# Resolve gameplay with exact grid rules

Pushing and falling will be determined by exact grid rules, with smooth animations presenting their results. Godot's physics simulation will not determine entity movement: predictable outcomes and reliable undo are more valuable for this framework than physical sliding, tipping, or tumbling. Gameplay resolution must therefore remain independent of animation timing and visual transforms.

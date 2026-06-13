## Vine Procedural Generation

MDDN242 2026 - Lukas Joy

This project is customizable procedural vine generation tool script intended for personal use. It does this through generation of meshes and mesh instancing.

The project was created using AI coding assistance and is made using Godot.

---
## Design Intent

### The goal

The main intent of this project was to be a stepping off point into procedural generation system for game design. The intent of the vine procedural generation system was to create a understandable, usable and game ready vine procedural generation system for me to use for any future projects.
### Why this direction

Procedural generation system are not something that I have played around with at all and also would force me to learn a lot of either new systems or more about systems in Godot such as script based mesh generation, raycasting, and normals. All creative control of the design process was handled by me I decide on how I wanted the vine system to work and what features it had and research how the best way to implement each features would be before writing complex and technical prompts for the AI to get exactly what I was looing for without any additional features.
### Who is this for

This is made for myself and for anyone who I work with on Godot project in the future. I wanted to gain an understanding of procedural generation systems and I want team members / co-workers to understand how to use the system easily.

---
## Inspiration & References

- [Ivy Studio - Procedural vine generation](https://assetstore.unity.com/packages/tools/particles-effects/ivy-studio-procedural-vine-generation-217205?aid=1100lJ2z) -  Initial inspiration for wanted to create a procedural vine generation system for Godot.
- [Tommaso Romano'](https://x.com/TommasoRomano_/status/1402631901337337857) - The base description of the surface walking raycast system was inspired by this.

---
## Ideation & Brainstorming

Before I committed to creating any sort of procedural generation system I considered a couple of other ideas but once I decided on procedural generation I only considered vines.

### Directions considered

1. Godot Signal Visualizer Plugin- A Godot plugin to visualize the signals between the different nodes within your Godot scenes. I didn't pursue because already existed.
2. Godot Object Orientated Programming Visual Planner Plugin - A Godot plugin to allow you to create UML diagrams to plan out the inheritance and composition of you project with auto signal and node creation. I didn't pursued because was much to big of a project for the time I had.
3. Godot Procedural Generation Tool Script - A Godot Tool script to create game ready level assets in editor, I did pursue as was interested in learning more about procedural generation and the systems around it.

---
## What I Tried That Did and Didn't Work

### 1: Using mesh data for face changes

**What I tried:** I tried for when the generate point using the surface walking recasts had normal direction variation between two points accessing the mesh data for the hit meshes to make the vine follow the surface more closely and not cut through corners.

**Why it didn't work:** This didn't work because the mesh data is complex and not made to be human understandable which made it hard to figure out what I needed from the mesh data. I didn't reach this point but I realized that this approach would not work if the found vine points where on different meshes.

What worked instead: Instead I used a system of raycasts to add additional surface point detail into the branch point arrays using raycasts from points that I could already guarantee weren't clipping through any geometry.

**What I learned:** From this I learnt that sometime the most simple approach is the best approach and that using variation of system or function that you are already using and using data that you already have can be helpful to remove contributing error factors.

### 2: Inverting raycast direction for overlapping points

**Issue:** I was running into an issue where because of the constant raycast length in the surface walking algorithm if the vine went around two 90 degree corners in a single step that the vine would often get stuck going back and forth between two points because of the vine attempting to go in roughly straight line from the start point not taking into a account the surface normal direction.

**What I did: In an attempt to fix this I made it so that if any point had a normal below horizontal I inverted the initial direction of the next surface walking algorithms raycast or landed on a already existing point I went back a step and inverted that starting points initial direction.

**Why it worked:** This worked because it canceled out the issue of trying to go in the same general direction for both vertical and horizontal double 90 degree turns with the below horizontal fixing any vertical flips and return point fixing any horizontal flips.

**What I learned:** Some times bugs are not present in the code and the issue is instead with the conceptual implementation of a system in this case the code was doing exactly as it was told and the issue was that I had not thought about the fact that if a vine went around a corner that the roughly straight line would suddenly be behind it.

### 3: Baking vines into a resource

**What I tried:** I tried for instead of having the vines be generated again on game begin instead have there be another in the editor that would bake the selected vine into a Godot resource file that could be used to load in the meshes for the vine at runtime.

**Why it didn't work:** This didn't work because the generate vine is made up of many meshes and instanced leave scenes so I was attempting to save all of this into a single Godot resource file and just kept on overriding the vines with the leaves or vice versa.

What worked instead: Instead I reparented the in editor generated meshes and instances from the editor memory onto the script parent making the generated meshes and instance present in the scene tree rather than just in the editor memory. This fixed the issue and increased performance as removed the step of attempting to save the meshes and place them into the scene on runtime and instead used the already generated meshes and just stored them in the scene instead of editor memory, increasing editor and script performance.

**What I learned:** From this I again learnt that using variation of system or function that you are already using and using data that you already have can be helpful to remove contributing error factors.

---
## AI & Prompting Process

### Tools used

- ChatGPT
- Claude
- Github Co-Pilot

### How you used them

ChatGPT was used via Github Co-Pilot in VS Code.

Claude was used via Github Co-Pilot in VS Code and via [https://claude.ai/](https://claude.ai/) with copying and pasting in and out of VS Code or Godot editor.

Above models were used in a combinatoin of Agent, Ask and Plan modes.

Github Co-Pilot was used via VS Code using the above models.

### What you used AI for

ChatGPT was used to make sure my initial structuring prompts were clear by asking it if there where holes in what the prompts were asking.

Claude was used to build the base overall structure of features implementation using the prompts engineered with assistance from ChatGPT as well as for bug fixing assistance.
### What worked

Prompts that specified specific coding principles, structures or functions for the AI to follow allowing little to no room for interpretation worked best as they gave the AI no room to decide to do other things or get confused with exactly what I was asking as well as asking the AI model if it understood what I was asking before it implemented anything.

```
use the original raycast up across down across up logic to find the points then cutrom to create a curve then check all normals between points to flag any sections where the normal changes then from the point on the smoothed catrom curve raycast out wards and using the normal in relation to the position on the curve between the two points and add the collision points as a new point between the repeat this 20 or so times for each section with normal variation

before implementing this does it make sense?
```

The above example was during the implementation of raycasts for surface changes, and shows how I was making sure to specify the specific information and data I wanted the model to work off and how to use that data as well as asking it if understood what I was asking.

### What didn't work

Prompts that were vague or used little or no technical language didn't work well as they gave the AI too much more to interpret the prompt causing the AI to change, edit, add or remove parts of the code/project that the AI was not intended to be working on.

No example as I tended to edit prompt again if I did a bad job so prompts no longer accessible.

---
## Technical Notes

### Tools & libraries

| Tool     | Purpose      |
| -------- | ------------ |
| Godot    | engine       |
| VS Code  | AI workspace |
| Github   | versioning   |
| Aseprite | texturing    |

---
## Reflection

### Marking
- Vines able to appear to follow real life vine behaviors.
	8/10 - Vines are mostly able to appear to follow real life behavior except for light dependent behaviors.
- Generated vine outcomes are savable, seedable and repeatable.
	9/10 - Outcome parameters can be saved to Godot recourse file and be reloaded for same outcome. How ever location not saved in any way.
- Vine attributes are editable without destroying previously generated vines direction and shape.
	10/10 - Vine procedural seeding continues on from same initial seed so extending length or changing trailing and or sagging or secondary branch factors does not destroy previous branch or branches generation.
- The project is easy to use with export parameters having easily predictable and understandable effects on the generated outcome.
	7/10 - Majority of export parameters have good descriptions and predictable effects however some are confusing in name or comment.
- Vines are performances conscious and usable for game ready set dressing.
	5/10 - Vines are quite tri heavy so may not be the most performances conscious or game ready.

### What I learned

I learned a lot about the system involved in procedural generation. I had a lot to learn when it came to the system around finding point on geometry as well mostly through the use of raycasting and normals.
### What I'd do differently

I wish I had more time to work on this project. If I started again tomorrow I would've spent a lot more time on this project however this lack of time was mostly caused by time crunch from other courses so I couldn't really do much about it.
### What I'm most proud of

The overall aesthetic outcome of the vines feel quite good. The specific application in the demo.exe I am quite happy with.

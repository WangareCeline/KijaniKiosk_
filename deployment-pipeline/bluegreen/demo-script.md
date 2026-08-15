# Demo Script for Nia

**Format:** Stage directions in brackets, spoken lines in plain text. Read aloud to the board.

---

[Screen shows the current live system, running normally]

"What you're looking at is our payment system, running right now, serving real traffic. Today I'm going to show you two things: how we release a new version without anyone noticing, and how we catch a problem and fix it faster than a person ever could."

[Engineer deploys the new version behind the scenes; screen shows it starting up]

"We're deploying a new version of the system now. It's starting up quietly, in the background, while the current version keeps serving everyone. Nobody using the app right now can tell anything is happening."

[Screen shows traffic switching to the new version]

"Now we flip the switch. All traffic moves to the new version. This happens in a fraction of a second, no downtime, no dropped requests."

[Engineer introduces a simulated problem into the new version]

"Now let's do something we don't normally do on purpose: I'm going to break it. This simulates what happens if a new release has a hidden bug that only shows up once it's live."

[Screen shows the automated system detecting the failure and switching back]

"Watch the screen. The system is checking on itself every few seconds. It just noticed something's wrong, and it's switching back to the last version that was working. No one had to notice, no one had to react. It just happened."

[Screen shows the system fully recovered, running the previous stable version]

"That recovery took eight seconds. A person watching a screen and reacting by hand took four minutes the last time we measured it. What you just saw is the difference between a system that protects itself and one that depends on someone catching it in time. That's what we're building toward for every part of this platform."

[End demo]

# Blue/Green vs. Containers: A Comparison for Nia

## Summary

We built and tested two different ways to deploy kk-payments safely. The first keeps two full copies of the service running on one machine and switches traffic between them. The second packages the service into a container and lets Kubernetes manage multiple copies, restarting anything that fails on its own. Both approaches were tested end to end today, not just designed on paper: we deployed a new version, switched traffic, broke it on purpose, and watched each system recover without a person stepping in.

The headline result: the container approach recovered from a failure without any recovery script running at all. When we deleted one of the two running copies of the service, Kubernetes noticed it was gone and started a replacement automatically, and because the image was already cached on the machine, the new copy was back up in the same second. The blue/green approach, by contrast, relies on a purpose-built monitoring script that watches for failures and switches traffic back, which completed a full rollback in 8 seconds during our test today. Both are fast. They get there in very different ways, and that difference matters for how much custom code we have to maintain going forward.

## Comparison Table

| Concern | Blue/Green Approach | Container Approach |
|---|---|---|
| Deployment mechanism | Two full copies of the service run side by side on one server, each on its own port. A new version is deployed to the idle copy and health-checked before it receives any traffic. | The application is packaged into a portable image, versioned, and pushed to a private registry. The cluster pulls the exact image needed and runs the requested number of copies. |
| Rollback mechanism | A separate script watches the live copy's health. If it starts failing, the script rewrites which copy is receiving traffic and reloads the traffic router, restoring the previous version. | There is no separate rollback script. If a new version is bad, we redeploy the previous image version the same way we deployed the new one, using the same versioned tag. |
| Failure recovery | Recovery depends entirely on the custom monitoring script we wrote and tested today. If that script has a bug or isn't running, nothing recovers automatically. | The cluster itself continuously checks that the requested number of copies are running. If one dies for any reason, a replacement starts automatically, with no custom script required. |
| Scaling | Scaling means manually setting up a third or fourth full copy of the service, each needing its own port and its own entry in the traffic router. This gets harder to manage as the number of copies grows. | Scaling is a single number in the deployment configuration. Asking for more copies is the same action whether you want two or twenty. |

## The Two Measured Numbers

**Self-healing time:** we deleted one of two running Pods and measured the time until its replacement was up. Because the image was already cached on the cluster from the original deployment, the replacement was running again within the same second, with no image download required. A production cluster with multiple machines would likely take longer for this exact scenario, since a replacement scheduled onto a machine that has never run the image before would need to download it first, but the automatic replacement itself is not something we had to build.

**Image size:** we built the same application two ways: a single build stage that includes the compiler and every development tool, and a two-stage build where the final image only contains the compiled code and what it needs to run. The single-stage version came out to 57.9MB. The two-stage version came out to 49.3MB, a reduction of about 14.9%. This is a modest saving because this particular application is small and simple. On a real payments service with more dependencies, database drivers, and testing tools, the gap between a single-stage and multi-stage build is typically much larger, because there is more development-only weight to strip out.

## What This Doesn't Yet Solve

The container approach we tested today runs on a single machine using Minikube, which is meant for development and testing, not production traffic. It doesn't yet address what happens if that one machine goes down entirely, since every copy of the service would go down with it. It also doesn't address how a new version gets tested against a small slice of real traffic before going fully live, the way a more cautious rollout would work. Both of these are solved by the same underlying technology once it's run properly, with multiple machines instead of one and finer control over how traffic is introduced to a new version, which is exactly what the next project builds on top of what we did here. Today's work proves the two core ideas: that a container-based deployment can recover from failure without a custom script, and that it can be built small and clean. The next step is proving it can do that reliably across a real, multi-machine environment.

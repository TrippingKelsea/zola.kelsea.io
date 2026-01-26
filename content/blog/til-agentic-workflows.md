+++
title = "TIL: Agentic Workflows"
date = "2024-09-24"

[taxonomies]
tags = ["Agentic-Workflows", "AWS"]

[extra]
slug = "til-agentic-workflows"
+++

# TIL: Agentic Workflows


Today I Learned: SRE Service Orchestration vs Agentic Workflows
In today’s evolving tech landscape, two approaches stand out in managing automation and autonomy within complex systems: SRE service orchestration and agentic workflows. While both paradigms aim to optimize systems, they serve distinct purposes and operate at different levels of complexity and autonomy. Here’s a breakdown of what I learned while comparing these two.

SRE Service Orchestration
Site Reliability Engineering (SRE) emphasizes automating the management of infrastructure and services. At its core, service orchestration refers to coordinating and automating workflows across distributed systems. This is often achieved by using a combination of API-to-API interactions, scheduled tasks, and predefined logic. The orchestration platform acts as a conductor, ensuring that various services communicate and operate in sync to achieve an overall goal.

In SRE, service orchestration focuses on:

Task automation: Executing specific sequences like scaling infrastructure, deploying updates, or managing incident responses.
Rule-based workflows: Tasks are typically predefined in a script or orchestration tool (e.g., Kubernetes for container orchestration), with little to no decision-making autonomy.
Deterministic execution: The sequence of operations is fixed, and outcomes are predictable based on the rules coded into the workflow.
Orchestration systems in SRE are excellent at maintaining reliability, ensuring processes happen consistently and according to plan. However, they rely heavily on predefined scripts and rules, meaning that adapting to real-time changes or unpredictable environments requires manual intervention or reprogramming.

Agentic Workflows
On the other hand, agentic workflows focus on building systems that can perceive, reason, and act autonomously. These workflows involve autonomous agents that gather data from their environment, make decisions based on that data, and take actions without needing explicit instructions at every step. The key characteristic of agentic workflows is their goal-oriented behavior, where agents are tasked with achieving a specific outcome and are given the freedom to decide how best to reach that outcome.

Agentic workflows differ from traditional SRE service orchestration in a few significant ways:

Autonomy: Agents make decisions based on real-time input, using learned patterns or adaptive algorithms (e.g., machine learning models). They can dynamically adjust their actions to changing environments, like predicting system load and preemptively scaling resources.
Context-awareness: These agents are aware of the broader system state, reacting not just to predefined rules but to live data and feedback loops.
Adaptation and learning: Agentic workflows often incorporate feedback mechanisms, allowing agents to improve their decision-making over time, evolving without manual intervention.
A good example of agentic workflows would be systems that automatically adjust infrastructure settings (like audio volume or server resources) based on user behavior and environmental factors. These agents make decisions proactively, as opposed to simply following a set of hard-coded rules.

Key Differences
Aspect	SRE Service Orchestration	Agentic Workflows
Control	Centralized, managed by orchestrators	Decentralized, agent-driven
Decision-making	Deterministic, predefined rules	Autonomous, real-time decision-making
Goal	Task automation	Goal-oriented autonomy
Adaptability	Requires manual updates for changes	Adapts dynamically to environmental changes
Learning	Static, rule-based	Learns from feedback, improves over time
Real-World Applications
In an SRE context, service orchestration is ideal for repetitive, predictable tasks where the sequence and outcome are well-defined. For example, orchestrating container deployments across multiple regions with Kubernetes or triggering backup jobs on schedule. It works well where reliability and precision are paramount but fails to handle real-time, unpredictable scenarios without manual intervention.

Agentic workflows, however, shine in environments where systems must continuously adapt, learn, and optimize performance based on changing conditions. Autonomous agents can predict and address problems before they escalate—like dynamically adjusting cloud resources or predicting server loads based on user activity. This approach is crucial in AI-driven systems, IoT, and complex adaptive environments where fixed orchestration rules would be insufficient.

Conclusion
SRE service orchestration is effective for task automation in predictable environments, while agentic workflows provide a more dynamic, adaptive approach suitable for complex, evolving systems. As technology demands more autonomous decision-making, agentic workflows may increasingly supplement or even replace traditional service orchestration, particularly in contexts where adaptability and learning are critical.


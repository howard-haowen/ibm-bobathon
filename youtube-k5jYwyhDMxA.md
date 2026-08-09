# YouTube 影片摘要：5 Terms You Need to Know About Agentic AI

**影片連結：** https://www.youtube.com/watch?v=k5jYwyhDMxA

---

## 摘要

1. **AGENTS.md**：放在專案根目錄的 Markdown 文字檔，告知 AI agent 該專案的指令、程式碼規範、測試命令等，是「專為 agent 設計的 README」。可嵌套多層，越接近工作目錄的規則優先覆蓋。

2. **Agent Skill（代理技能）**：一個資料夾結構，內含 `SKILL.md` 及所需腳本或資源。`SKILL.md` 的 description 欄位告訴 agent 何時應載入此技能（例如「當使用者要製作 PowerPoint 時」），若任務不相關則不佔用 context window。

3. **MCP（Model Context Protocol）**：開放協定，用於連接 AI 應用與外部工具、資料來源及工作流程。MCP Server 將外部工具包裝成標準介面，任何支援 MCP 的 agent 都能與其溝通（如 Notion、Stripe 等）。

4. **A2A（Agent-to-Agent）**：由 Google 提出的開放協定，讓 agent 之間互相溝通與協作。每個 agent 發布一張「Agent Card」描述自身功能，其他 agent 可讀取後進行任務委派（如採購 agent → 財務 agent 審批）。

5. **Subagents（子代理）**：主 agent 可生成子 agent 來處理特定子任務，每個子 agent 擁有獨立的 context window，完成後回傳結果。適用於任務過大或可並行處理的情境（如同時執行 20 項獨立檢查）。

---

## 逐字稿

[0:00] Frontier AI agents, they're pretty capable.
[0:00] They're really good at planning out tasks and writing code with minimal human involvement  
[0:00] but there are a handful of specific pieces under the hood that enable this.
[0:00] So let's cover five of those pieces, the five terms you need to know about agentic  
[0:00] AI and let's start with stuff that's inside the agent that kind of shapes how it behaves.
[0:00] Inside an agent of course there is a model, a large language model.
[0:00] That's what's doing the actual text generation and the reasoning and by  
[0:00] itself well it's just a conversational partner.
[0:00] What turns it into an agent is the instruction layer that's wrapped around the model.
[0:00] So that brings us to term number one, term number one that you need to know, that is agents.md.
[0:00] So what's that?
[0:00] Well, .md, that's markdown, so it's just a text file.
[0:00] It sits at the root of a project, and whenever the agent starts work in that project,  
[0:00] it reads whatever is in that agent's .mdfile.
[0:00] Now the file tells the agent things like which commands to run for tests  
[0:00] or which coding conventions this code base uses.
[0:00] So we can really think of this as being kind of like a...
[0:00] Readme file but it's a readme files specifically written for agents.
[0:00] It tells the agents things like specific setup commands to use  
[0:00] and any code style rules or maybe how a PR title should be formatted.
[0:00] So the agent executes the commands it finds in agents.md when they're contextually relevant.
[0:00] So if the file says run PMPM test before committing well then the  
[0:00] agent will run PMPM test before it does a commit.
[0:00] And agents.md files can also be nested, meaning there can be multiple of them.
[0:00] So maybe we have one at the root and then multiple  
[0:00] other ones for sub-projects with its own set of rules.
[0:00] And files that are closer to the working directory  
[0:00] override the earlier ones because they appear later.
[0:00] Now agents.md was introduced by OpenAI and later contributed to the agentic AI
[0:00] foundation that runs under the Linux foundation.
[0:00] Now a quick wrinkle worth mentioning here some agents use a different  
[0:00] file name from agents.md so Claude for example does this.
[0:00] Claude's one that is actually called Claude.md because of course it is so  
[0:00] it's different name but it's more or less the same idea.
[0:00] So agents.md is read by an agent every time it starts work in a given project.
[0:00] But what about knowledge that the agent only needs sometimes and isn't necessarily project specific.
[0:00] So let's say the agent needs to know how to build a PowerPoint deck.
[0:00] Well, loading all of that context every single time the agent starts,
[0:00] that would just really clog up the context window for no real reason  
[0:00] if the task at hand has nothing to do with PowerPoint slides.
[0:00] So that brings us to term number two and term number two is
[0:00] agent skill so what's that well an agent skill is  
[0:00] a folder and inside that folder is a file that file is called skill.md.
[0:00] So .md again that's more markdown now also in that  
[0:00] folder is whatever scripts or resources the task needs and then inside skill.
[0:00] Md is some metadata including a description.
[0:00] And that tells the agent something like, invoke me when the user wants to X.
[0:00] So X could be when the use wants to make a PowerPoint.
[0:00] And if the user's request matches that description, the agent pulls the skill in.
[0:00] If it doesn't match, well, the skill is just gonna kind of sit  
[0:00] there out of the way, not taking up any context.
[0:00] Agent skills are another open standard and they're supported by multiple agent platforms.
[0:00] Agents.md, that's how a specific project works,  
[0:00] and an agent skill tells the agent how to do a specific kind of task.
[0:00] All right, so that's two of our five terms down.
[0:00] The agent now knows what to do, but doing things also means reaching outside the box,  
[0:00] as in outside the AI agent itself.
[0:00] So that's where we're going to go next.
[0:00] So agents need to reach all kinds of external things like APIs or databases  
[0:00] or developer tools or SaaS platforms you name it.
[0:00] And the challenge here is that every one of those targets might have its own interface.
[0:00] So without some kind of standard every AI agent would need a custom  
[0:00] connector for every external thing it might touch which would be a mess.
[0:00] So that brings us to term number three, MCP - Model Context Protocol.
[0:00] Now MCP is an open protocol for connecting AI applications to tools and data sources  
[0:00] and workflows and it comes with something called an MCP server.
[0:00] Now an MCP server wraps up a tool or a data source in a standard interface  
[0:00] and any agent that can speak MCP can now talk to that tool.
[0:00] So let's say an agent needs to pull data from it needs to go to something in Notion.
[0:00] So we've got Notion here, or maybe it needs to go a Stripe payment link, whatever the backend is.
[0:00] Well, the agent speaks MCP to the server and it's  
[0:00] the server now that handles the underlying API for in this case, Notion.
[0:00] Now, MCP started at Anthropic and is now governed under the AAIF,  
[0:00] again at the Linux foundation.
[0:00] And it has broad industry support.
[0:00] So that covers agents talking to tools and data.
[0:00] What about agents talking other agents?
[0:00] Well, time for term number four.
[0:00] That is A2A.
[0:00] Otherwise known as agent to agent.
[0:00] So A2A is an open protocol for agent to agent communication.
[0:00] So let's kind of think of a scenario for using this.
[0:00] Let's say we've got a procurement agent here and that handles vendor contracts.
[0:00] And then maybe we've also got a finance agent over here and that approves spend.
[0:00] And yeah, I know financial processing stuff, trying to contain your excitement but the the 
[0:00] procurement agent needs to negotiate a contract and then it needs to hand off  
[0:00] to the finance for approval and without A2A these two agents would need some form of custom integration
[0:00] or they wouldn't really coordinate very well but with A2A each agent publishes something called an  
[0:00] agent cart. And that's just basically a description of what the agent does and how to talk to it.
[0:00] And other agents can read that card and then figure out how to delegate work.
[0:00] The procurement agent in this case is going to find the agent card and  
[0:00] read it for the finance agent and then hand off the contract.
[0:00] So that's A2A and this A2A standard comes from Google.
[0:00] It's now also an open standard under, you guessed it, the Linux foundation.
[0:00] So MCP is how agents talk to tools and data and A2A is how agent's talk to each other.
[0:00] All right, so how we're doing here,  
[0:00] now the agent knows what to do and it knows how to reach outside of its borders.
[0:00] What else?
[0:00] Well, sometimes one agent just isn't enough.
[0:00] Maybe the task is too big for one context window,
[0:00] so say the agent's reviewing a code base with thousands of files loading every file,  
[0:00] that would blow out the context on its own.
[0:00] Or maybe the work is embarrassingly parallel,  
[0:00] like you've got to run a check on 20 different functions and each check is independent,
[0:00] and you could do those one at a time but that's slow,  
[0:00] doing them all at once would be 20 times faster.
[0:00] So, term number five that you need to know.
[0:00] It's subagents, which means using and spawning multiple agents.
[0:00] So a subagent is a child agent that the main agent spawns to do a specific piece of work
[0:00] and each sub agent runs in its own fresh context window,  
[0:00] it does its job and it returns a result when it is done.
[0:00] So this main agent here, it could spawn a sub agent and give it some work to do.
[0:00] Let's say go read 500 files, and then just kind of hand back to the  
[0:00] main agent a summary of those files.
[0:00] So that would keep the main agents context window pretty clean.
[0:00] And we could have lots of agents in parallel, maybe we've got like 20  
[0:00] agents here running in parallel handling 20 independent checks at the same time.
[0:00] Now, sub agents are a little bit different from the other  
[0:00] four terms because sub agents are a common pattern in modern
[0:00] agent systems but they don't really have a formal standard document behind them.
[0:00] But the concept shows up almost identically everywhere.
[0:00] I mean the very basic idea is you have this big parent agent here.
[0:00] That parent agent spawns one or more child agents.
[0:00] The child gets the same context.
[0:00] The child does whatever work it was told to do  
[0:00] and then it returns a result and the parent carries on.
[0:00] With its context intact.
[0:00] So there we've got five terms.
[0:00] We've got agents.md and agent skills, which live inside the agent and they shape how it behaves.
[0:00] We've go MCP and we've go A2A.
[0:00] That's how the agent reaches outwards to tools and to other agents.
[0:00] And we've gone sub agents.
[0:00] That's the agent handles the work that doesn't fit into one context.
[0:00] That's what a front-end AI agent actually looks like under the hood today.

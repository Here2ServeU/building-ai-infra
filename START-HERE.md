# Start here

New to AI infrastructure? This page is your map. You don't need a cloud account, a GPU, or any experience to start.

## Who this is for

- **Complete beginners** who want to understand how AI platforms really work.
- **Engineers** moving into DevOps, platform, SRE or MLOps roles.
- **Anyone following the [Building AI Infrastructure](docs/series/README.md) video series.**

## Your path, one step at a time

| Step | Do this | Time | Cost |
|:-:|---|---|---|
| 1 | Read the **Part 1** summary: [PDF](docs/series/pdf/part-1-building-blocks.pdf) · [web](docs/series/part-1-building-blocks.md) | 15 min | $0 |
| 2 | Run the demo API on your laptop ([below](#your-first-10-minutes)) | 10 min | $0 |
| 3 | **Part 2:** build all 8 blocks on your laptop: [PDF](docs/series/pdf/part-2-laptop.pdf) | 1 hour | $0 |
| 4 | Set a **budget alert** and request **GPU quota** on one cloud | 15 min | $0 |
| 5 | Pick one cloud: **Part 3** [AWS](docs/series/pdf/part-3-aws.pdf), **Part 4** [Azure](docs/series/pdf/part-4-azure.pdf) or **Part 5** [Google Cloud](docs/series/pdf/part-5-gcp.pdf) | 2 hours | a few $, if you destroy the same day |
| 6 | **Part 6:** [On-prem](docs/series/pdf/part-6-on-prem.pdf) (read, even if you have no data center) | 20 min | $0 |
| 7 | **Part 7:** [One platform](docs/series/pdf/part-7-one-platform.pdf): explore this repo's fleet | 1 hour | $0 to read |

Stuck on a word? See the [glossary](docs/glossary.md).

## Your first 10 minutes

You need `git`, `go` and `make`. The first command tells you if anything is missing, and how to install it.

```bash
git clone https://github.com/Here2ServeU/building-ai-infra
cd building-ai-infra
make doctor          # checks your tools; installs nothing
make start           # starts the demo API (leave this terminal open)
```

In a **second terminal**, ask it questions:

```bash
make ask Q="what is a GPU node pool?"
make ask Q="how do I keep my cloud bill near zero?"
make ask Q="what is GitOps?"
```

**What just happened?** You ran the same Go API that this platform deploys to Kubernetes, in **stub mode**: it searches a small built-in set of notes instead of a real vector database. That's a tiny version of **RAG** (retrieval-augmented generation), the pattern behind most AI assistants. Press `Ctrl+C` in the first terminal to stop it.

## What's in this repo, in plain words

| Folder | What it is | Which part |
|---|---|---|
| `docs/series/` | Chapter summaries (web + PDF) for every part | All |
| `apps/` | The two apps: a Go question-answering API and a Python document loader | 2, 7 |
| `terraform/` | Code that **builds** cloud infrastructure (networks, clusters, GPU pools) | 3, 4, 5 |
| `helm/charts/` | **Packages** that install the apps on Kubernetes | 2–7 |
| `flux/` and `argocd/` | **GitOps**: what each cluster should run, pulled from Git. Pick one tool | 7 |
| `observability/` | Dashboards, alert rules and SLOs | 2, 5, 7 |
| `docs/runbooks/` | What to do when each alert fires | 7 |
| `scripts/` | Helper scripts (tool check, chaos tests, self-healing) | All |

## Three rules that save you money

1. **Set a budget alert before you create anything in a cloud.** Something like $10/month, with emails at 50/90/100%.
2. **Plan before you apply.** `terraform plan` shows what will be built before anything exists.
3. **Destroy the same day.** `make tf-destroy ENV=dev`, then check the console for leftover load balancers, disks and public IPs.

## Handy commands

```bash
make help        # every shortcut, grouped
make doctor      # which tools you have
make start       # demo API on your laptop
make ask Q="..." # ask the demo API
make pdfs        # rebuild the chapter PDFs (needs pandoc + Chrome)
```

## Where to get help

- Step-by-step labs, scripts and live help: the AI/ML Membership at [transformed2succeed.com](https://transformed2succeed.com/membership)
- Articles: [emmanuelnaweji.com](https://emmanuelnaweji.com)
- Found a problem? Open an issue on GitHub.

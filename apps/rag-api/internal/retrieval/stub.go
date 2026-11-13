package retrieval

import (
	"context"
	"hash/fnv"
	"math"
	"sort"
	"strings"
	"unicode"
)

// Stub mode lets the API run on a laptop with no embedder and no vector DB.
// It turns text into a simple bag-of-words vector and searches a small
// in-memory set of notes about the 8 building blocks from the course.
// It is for learning and demos only: real deployments use the HTTP embedder
// and Qdrant (see New).

const stubDims = 256

// NewStub returns a Retriever backed by an in-memory embedder and store.
func NewStub(cfg Config) *Retriever {
	if cfg.TopK <= 0 {
		cfg.TopK = 3
	}
	emb := stubEmbedder{}
	store := newMemoryStore(emb, stubCorpus)
	return &Retriever{embedder: emb, store: store, cfg: cfg}
}

type stubEmbedder struct{}

func (stubEmbedder) Embed(_ context.Context, text string) ([]float32, error) {
	return bagOfWords(text), nil
}

func bagOfWords(text string) []float32 {
	vec := make([]float32, stubDims)
	words := strings.FieldsFunc(strings.ToLower(text), func(r rune) bool {
		return !unicode.IsLetter(r) && !unicode.IsDigit(r)
	})
	for _, w := range words {
		if len(w) < 3 || stopWords[w] {
			continue
		}
		h := fnv.New32a()
		_, _ = h.Write([]byte(w))
		vec[h.Sum32()%stubDims]++
	}
	var norm float64
	for _, v := range vec {
		norm += float64(v * v)
	}
	if norm > 0 {
		n := float32(math.Sqrt(norm))
		for i := range vec {
			vec[i] /= n
		}
	}
	return vec
}

var stopWords = map[string]bool{
	"the": true, "and": true, "for": true, "what": true, "how": true, "does": true,
	"are": true, "with": true, "that": true, "this": true, "you": true, "your": true,
	"why": true, "when": true, "who": true, "which": true, "from": true, "into": true,
}

type memoryStore struct {
	docs []Document
	vecs [][]float32
}

func newMemoryStore(emb stubEmbedder, docs []Document) *memoryStore {
	s := &memoryStore{docs: docs}
	for _, d := range docs {
		v, _ := emb.Embed(context.Background(), d.Metadata["title"]+" "+d.Text)
		s.vecs = append(s.vecs, v)
	}
	return s
}

func (s *memoryStore) Search(_ context.Context, vec []float32, topK int) ([]Document, error) {
	out := make([]Document, 0, len(s.docs))
	for i, d := range s.docs {
		var dot float32
		for j := range vec {
			dot += vec[j] * s.vecs[i][j]
		}
		if dot <= 0 {
			continue
		}
		d.Score = dot
		out = append(out, d)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Score > out[j].Score })
	if len(out) > topK {
		out = out[:topK]
	}
	return out, nil
}

func note(id, title, text string) Document {
	return Document{ID: id, Text: text, Metadata: map[string]string{"title": title, "source": "stub"}}
}

var stubCorpus = []Document{
	note("block-1", "Compute (the stove)", "Compute is where the work runs. CPUs handle everyday work like APIs and data jobs. GPUs do the heavy math for training and large models. GPUs are expensive, so put them in a GPU node pool that scales from zero and turn them off when idle."),
	note("block-2", "Data and storage (the pantry)", "Object storage such as S3, Azure Blob, Google Cloud Storage or MinIO holds raw data, training sets and versioned model files. Fast disks feed the GPUs so they never sit waiting for data."),
	note("block-3", "Networking (hallways and doors)", "Each platform gets a private network (VPC or VNet) split into subnets. Users come in through one front door, a load balancer. Data and GPUs are never directly on the internet."),
	note("block-4", "Orchestration (the head chef)", "Apps run in containers. Kubernetes places containers, restarts them when they crash and adds copies when busy. Managed Kubernetes is EKS on AWS, AKS on Azure, GKE on Google Cloud, and OpenShift on-premises."),
	note("block-5", "MLOps (the recipe book)", "Pipelines train models the same way every time. A model registry such as MLflow keeps every version with its data, settings and score. Gates stop a worse model from replacing a better one."),
	note("block-6", "Serving (the serving window)", "Serving turns a model into an API. It scales with demand, and new versions go out as a canary: ten percent of traffic first, then the rest. KServe serves classic models and vLLM serves large language models."),
	note("block-7", "Observability (the inspector)", "Metrics, logs and traces show what the platform is doing. An SLO such as 99.9 percent of requests succeed defines good enough. Burn-rate alerts wake someone only when users are really affected. Tools: Prometheus, Grafana, Loki, Tempo, OpenTelemetry."),
	note("block-8", "Guardrails (locks, keys, budget)", "Identity uses least privilege: every person and pod gets only the access it needs, with workload identity instead of passwords. Secrets live in a vault, never in code. Budgets, cost alerts and OpenCost keep spending visible."),
	note("gitops", "GitOps", "GitOps means Git is the source of truth. Every change is a pull request. Flux or Argo CD in each cluster pulls the desired state from Git and reverts manual drift. Rollback is a git revert."),
	note("gpu-pool", "GPU node pool that scales to zero", "A GPU node pool starts at zero machines and has a taint so only pods that request nvidia.com/gpu land there. When a GPU pod is pending, the cluster autoscaler adds a node. When the work is gone, the pool shrinks back to zero, so you only pay while the GPU works."),
	note("cost", "Keeping your cloud bill near zero", "To keep the cloud bill and cost low, set a budget alert before creating anything. Request GPU quota early. Plan before apply, then build, learn and destroy on the same day. Check for leftover load balancers, disks and public IPs."),
	note("dr", "Disaster recovery", "Active-passive keeps one primary and a standby elsewhere with data copied on a schedule. Active-active serves from two sites at once and is harder and more expensive. Write RTO and RPO targets and run the drill: an untested plan is a hope, not a plan."),
}

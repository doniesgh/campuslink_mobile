/// Real response printed by the backend tests (backend/test), copied as-is
/// so the app and the API stay in agreement.
library;

/// GET /jobs after the seed (from before offers had `authorId` / `canEdit`:
/// also shows that an older API still reads fine).
const jobsJson = r'''
[{"id":"instadeep-ml","featuredLabel":"FEATURED RESEARCH OPENING","title":"Junior AI & ML Research Intern","company":"InstaDeep Ltd","location":"Centre Urbain Nord, Tunis","tags":["PFE 2025","Hybrid (3 days on-site)","Coeff PFE 20.0"],"stipendTnd":1200,"durationMonths":6,"period":"Feb – Jul 2025","labGroup":"RL & AI","labGroupNote":"Decision Lab","workspaceTitle":"Tunis Lab Workspace & Cohort","workspaceBadges":["14 Student Alumni · Current Interns","Bi-weekly London Sync"],"mission":"You will embed alongside the research group, translating theoretical breakthrough papers into high-performance reinforcement learning benchmarks and scalable multi-agent systems.","missionItems":[{"title":"Deep RL Benchmarking","description":"Design, iterate, and benchmark novel exploration strategies using PyTorch, JAX, and Flash-Attention primitives."},{"title":"Global Research Bridges","description":"Collaborate directly with lead research scientists across Tunis & London offices, presenting fortnightly lab findings."},{"title":"Production-Grade Rollouts","description":"Package validated algorithms into reproducible, open-source-ready containers for high-performance computing clusters."}],"matchPercent":94,"criteria":["Strong foundational grasp of Python, Linear Algebra, and Deep RL algorithms.","Registered in 4th/5th year at ESPRIT or equivalent engineering university (Graduation 2025).","Demonstrated GitHub contributions, personal ML builds, or coursework in PyTorch/JAX."],"skills":["PyTorch","JAX","Reinforcement Learning","Git/Docker","CUDA"],"hasApplied":false},{"id":"nimbus-backend","featuredLabel":null,"title":"Backend Engineering Intern","company":"Nimbus Labs","location":"Lac 2, Tunis","tags":["PFE 2025","On-site"],"stipendTnd":900,"durationMonths":6,"period":"Feb – Jul 2025","labGroup":"Platform","labGroupNote":"Core API team","workspaceTitle":"Nimbus Lab Workspace","workspaceBadges":["8 Current Interns"],"mission":"Build and operate REST services used by thousands of students.","missionItems":[{"title":"API Development","description":"Design and ship Node.js endpoints backed by MongoDB."}],"matchPercent":81,"criteria":["Solid Node.js and REST fundamentals.","Comfortable with Git and code reviews."],"skills":["Node.js","MongoDB","Docker"],"hasApplied":false},{"id":"carthage-robotics","featuredLabel":null,"title":"Computer Vision Intern","company":"Carthage Robotics","location":"Ghazela Technopark","tags":["PFE 2025","Hybrid (2 days on-site)"],"stipendTnd":1000,"durationMonths":5,"period":"Mar – Jul 2025","labGroup":"Vision","labGroupNote":"Perception Lab","workspaceTitle":"Carthage Robotics Lab","workspaceBadges":["6 Current Interns"],"mission":"Prototype perception pipelines for autonomous warehouse robots.","missionItems":[{"title":"Perception Prototyping","description":"Train and evaluate detection models on real robot footage."}],"matchPercent":76,"criteria":["Experience with OpenCV or PyTorch.","Interest in robotics."],"skills":["Python","OpenCV","PyTorch"],"hasApplied":false}]
''';

/// POST /jobs by a company (Medina Soft), as the backend answered it.
const postedJobJson = r'''
{"id":"6af7380cf0f064d239616440","featuredLabel":null,"title":"Flutter Mobile Intern","company":"Medina Soft","location":"Lac 1, Tunis","tags":["PFE 2026"],"stipendTnd":null,"durationMonths":6,"period":"Feb – Jul 2026","labGroup":null,"labGroupNote":null,"workspaceTitle":null,"workspaceBadges":[],"mission":"Build the Flutter app our clients use to book appointments every day.","description":"Build the Flutter app our clients use to book appointments every day.","missionItems":[],"matchPercent":null,"criteria":[],"skills":["Flutter","Dart"],"hasApplied":false,"authorId":"6af7380cf0f064d23961643f","canEdit":true}
''';

/// POST /jobs/instadeep-ml/summary (with a fake OpenRouter).
const jobSummaryJson = r'''
{"summary":"A 6-month research internship in reinforcement learning at InstaDeep, in Tunis.","keyPoints":["Benchmark new RL exploration strategies","Work with the London research team","6 months, Feb – Jul 2025","1200 TND per month"],"skills":["PyTorch","JAX","Reinforcement Learning"],"idealFor":"A 5th-year student who enjoys research and Python.","model":"anthropic/claude-haiku-5.5","cached":false}
''';

/// POST /jobs/:id/summary on a server without OPENROUTER_API_KEY (503).
const aiUnavailableJson = r'''
{"message":"AI features are not available on this server.","code":"AI_UNAVAILABLE"}
''';

/// POST /jobs by a student (403).
const postForbiddenJson = r'''
{"message":"Only companies and administrators can post offers."}
''';

/// POST /jobs with a 2-character title (422).
const postInvalidJson = r'''
{"message":"The title needs at least 3 characters.","code":"VALIDATION_ERROR"}
''';

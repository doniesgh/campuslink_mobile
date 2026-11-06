import type { Types } from 'mongoose';

import { JobApplicationModel, JobModel } from './jobs.model';

// The offers of the app's MockJobRepository.
const DEMO_JOBS = [
  {
    _id: 'instadeep-ml',
    featuredLabel: 'FEATURED RESEARCH OPENING',
    title: 'Junior AI & ML Research Intern',
    company: 'InstaDeep Ltd',
    location: 'Centre Urbain Nord, Tunis',
    tags: ['PFE 2025', 'Hybrid (3 days on-site)', 'Coeff PFE 20.0'],
    stipendTnd: 1200,
    durationMonths: 6,
    period: 'Feb – Jul 2025',
    labGroup: 'RL & AI',
    labGroupNote: 'Decision Lab',
    workspaceTitle: 'Tunis Lab Workspace & Cohort',
    workspaceBadges: ['14 Student Alumni · Current Interns', 'Bi-weekly London Sync'],
    mission:
      'You will embed alongside the research group, translating theoretical ' +
      'breakthrough papers into high-performance reinforcement learning benchmarks ' +
      'and scalable multi-agent systems.',
    missionItems: [
      {
        title: 'Deep RL Benchmarking',
        description:
          'Design, iterate, and benchmark novel exploration strategies using ' +
          'PyTorch, JAX, and Flash-Attention primitives.',
      },
      {
        title: 'Global Research Bridges',
        description:
          'Collaborate directly with lead research scientists across Tunis & ' +
          'London offices, presenting fortnightly lab findings.',
      },
      {
        title: 'Production-Grade Rollouts',
        description:
          'Package validated algorithms into reproducible, open-source-ready ' +
          'containers for high-performance computing clusters.',
      },
    ],
    matchPercent: 94,
    criteria: [
      'Strong foundational grasp of Python, Linear Algebra, and Deep RL algorithms.',
      'Registered in 4th/5th year at ESPRIT or equivalent engineering university (Graduation 2025).',
      'Demonstrated GitHub contributions, personal ML builds, or coursework in PyTorch/JAX.',
    ],
    skills: ['PyTorch', 'JAX', 'Reinforcement Learning', 'Git/Docker', 'CUDA'],
  },
  {
    _id: 'nimbus-backend',
    featuredLabel: null,
    title: 'Backend Engineering Intern',
    company: 'Nimbus Labs',
    location: 'Lac 2, Tunis',
    tags: ['PFE 2025', 'On-site'],
    stipendTnd: 900,
    durationMonths: 6,
    period: 'Feb – Jul 2025',
    labGroup: 'Platform',
    labGroupNote: 'Core API team',
    workspaceTitle: 'Nimbus Lab Workspace',
    workspaceBadges: ['8 Current Interns'],
    mission: 'Build and operate REST services used by thousands of students.',
    missionItems: [
      {
        title: 'API Development',
        description: 'Design and ship Node.js endpoints backed by MongoDB.',
      },
    ],
    matchPercent: 81,
    criteria: ['Solid Node.js and REST fundamentals.', 'Comfortable with Git and code reviews.'],
    skills: ['Node.js', 'MongoDB', 'Docker'],
  },
  {
    _id: 'carthage-robotics',
    featuredLabel: null,
    title: 'Computer Vision Intern',
    company: 'Carthage Robotics',
    location: 'Ghazela Technopark',
    tags: ['PFE 2025', 'Hybrid (2 days on-site)'],
    stipendTnd: 1000,
    durationMonths: 5,
    period: 'Mar – Jul 2025',
    labGroup: 'Vision',
    labGroupNote: 'Perception Lab',
    workspaceTitle: 'Carthage Robotics Lab',
    workspaceBadges: ['6 Current Interns'],
    mission: 'Prototype perception pipelines for autonomous warehouse robots.',
    missionItems: [
      {
        title: 'Perception Prototyping',
        description: 'Train and evaluate detection models on real robot footage.',
      },
    ],
    matchPercent: 76,
    criteria: ['Experience with OpenCV or PyTorch.', 'Interest in robotics.'],
    skills: ['Python', 'OpenCV', 'PyTorch'],
  },
];

/**
 * Demo data for this module. Called by `npm run seed` with the demo
 * student's id. Must be idempotent (safe to run again).
 *
 * Rewrites the demo offers and clears the demo student's applications (they
 * start with none, as in the mock), so the "Apply" flow can be shown again.
 * Other students' applications are kept.
 */
export async function seedJobs(demoUserId: Types.ObjectId): Promise<void> {
  for (const job of DEMO_JOBS) {
    await JobModel.replaceOne({ _id: job._id }, job, { upsert: true, runValidators: true });
  }
  await JobApplicationModel.deleteMany({ userId: demoUserId });
}

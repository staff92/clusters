module.exports = {
  repositories: ["staff92/clusters"],
  gitAuthor: "Renovate Bot <renovate@gmail.com>",
  platform: "github",
  schedule: ["at any time"],
  prCreation: "immediate",
  prConcurrentLimit: 10,
  prHourlyLimit: 0,
  dependencyDashboard: true,

  flux: {
    enabled: true,
    managerFilePatterns: [
      "/clusters/clusters/infrastructure/prod/.+\\.ya?ml$/",
    ],
  },

  "helm-values": {
    managerFilePatterns: [
      "/clusters/clusters/infrastructure/prod/.+values(-[a-zA-Z0-9]+)?\\.ya?ml$/",
    ],
  },

  packageRules: [
    {
      matchDatasources: ["docker"],
      groupName: "Docker images",
      automerge: false,
      versioning: "docker",
    },
    {
      matchDatasources: ["helm"],
      groupName: "Helm charts",
      automerge: false,
    },
    {
      matchDatasources: ["docker"],
      matchCurrentValue: "/^(latest|main|master|dev)$/",
      enabled: false,
    },
  ],

  customManagers: [
    {
      customType: "regex",
      managerFilePatterns: [
        "/clusters/clusters/infrastructure/prod/.+\\.ya?ml$/",
      ],
      matchStrings: [
        "image:\\s*['\"]?(?<depName>[a-z0-9][a-z0-9._\\-/]*(?:/[a-z0-9._\\-]+)*):(?<currentValue>[a-zA-Z0-9._\\-]+)['\"]?",
      ],
      datasourceTemplate: "docker",
    },
  ],

  ignorePaths: [
    "**/.github/**",
    "**/archive/**",
    "**/mail/**",
    "**/provisioning/**",
    "**/flux-system/**",
  ],
};

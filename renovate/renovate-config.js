module.exports = {
  repositories: ["staff92/clusters"],
  gitAuthor: "Renovate Bot <renovate@gmail.com>",
  platform: "github",
  schedule: ["every 17th of month"],
  prCreation: "immediate",
  prConcurrentLimit: 10,
  prHourlyLimit: 0,

  flux: {
    fileMatch: ["\\.ya?ml$"],
  },

  helmValues: {
    fileMatch: ["\\.ya?ml$"],
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
      matchDatasources: ["helm"],
      matchUpdateTypes: ["patch"],
      automerge: false, 
    },
    {
      matchDatasources: ["docker"],
      matchCurrentValue: "/^(latest|main|master|dev)$/",
      enabled: false,
    },
  ],

  customManagers: [
    // Images manifests Kubernetes
    {
      customType: "regex",
      fileMatch: ["\\.ya?ml$"],
      matchStrings: [
        // Format: image: registry/name:tag
        "image:\\s*['\"]?(?<depName>[a-z0-9][a-z0-9._\\-/]*(?:/[a-z0-9._\\-]+)*):(?<currentValue>[a-zA-Z0-9._\\-]+)['\"]?",
      ],
      datasourceTemplate: "docker",
    },
    // HelmRelease chart version
    {
      customType: "regex",
      fileMatch: ["\\.ya?ml$"],
      matchStrings: [
        "chart:\\s*\\n\\s+spec:\\s*\\n\\s+chart:\\s*(?<depName>[^\\n]+)\\s*\\n\\s+version:\\s*(?<currentValue>[^\\n]+)\\s*\\n\\s+sourceRef:",
      ],
      datasourceTemplate: "helm",
    },
  ],

  ignorePaths: [
    "**/.github/**",
    "**/archive/**",
  ],
};

module.exports = {
  // Repo(s) à scanner
  repositories: ["staff92/clusters"],

//   // Auteur des commits
//   gitAuthor: "Renovate Bot <renovate@gmail.com>",

  // Plateforme
  platform: "github",

  // Fréquence
  schedule: ["before 6am on monday"],

  // Créer des PRs automatiquement
  prCreation: "immediate",

  // Limite de PRs ouvertes en même temps
  prConcurrentLimit: 5,

  // Grouper les updates par type
  packageRules: [
    {
      // Grouper toutes les images Docker/OCI (Flux HelmRelease, etc.)
      matchDatasources: ["docker"],
      groupName: "Docker images",
      automerge: false,
    },
    {
      // Helm charts
      matchDatasources: ["helm"],
      groupName: "Helm charts",
      automerge: false,
    },
  ],

  // Pour Flux CD - détecter les fichiers HelmRelease et kustomization
  customManagers: [
    {
      customType: "regex",
      fileMatch: ["\\.ya?ml$"],
      matchStrings: [
        // Détecte les tags d'image dans les values Helm via Flux
        "image:\\s*(?<depName>[^:]+):(?<currentValue>[^\\s]+)",
      ],
      datasourceTemplate: "docker",
    },
  ],

  // Ignorer certains paths si besoin
  ignorePaths: [
    "**/.github/**",
  ],
};

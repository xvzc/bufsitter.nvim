module.exports = {
  extends: ["@commitlint/config-conventional"],
  parserPreset: {
    name: "conventional-changelog-conventionalcommits",
    presetConfig: {
      types: [
        { type: "feat", section: "Features" },
        { type: "fix", section: "Bug Fixes" },
        { type: "docs", section: "Documentation", hidden: false },
        { type: "perf", section: "Performance", hidden: false },
      ],
    },
  },
  rules: {
    'type-enum': [
      2, 
      'always', 
      ["build", "chore", "ci", "docs", "feat", "fix", "perf", "refactor", "revert", "style", "test"],
    ]
  }
};

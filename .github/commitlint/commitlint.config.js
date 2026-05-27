module.exports = {
  extends: ["@commitlint/config-conventional"],
  rules: {
    // tipos permitidos (Conventional Commits padrão + "wip" para commits de trabalho local)
    "type-enum": [
      2,
      "always",
      ["feat", "fix", "docs", "chore", "refactor", "perf", "test", "ci", "revert", "wip"],
    ],
    "subject-case": [0],   // permite maiúsculas (útil em PT-BR)
    "body-max-line-length": [0],
  },
};

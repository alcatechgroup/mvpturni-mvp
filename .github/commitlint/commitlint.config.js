module.exports = {
  extends: ["@commitlint/config-conventional"],
  rules: {
    // Tipos permitidos. Combina o vocabulário Conventional Commits padrão com os
    // tipos próprios do fluxo orientado a decisões/documentos do Turni (já em uso
    // consolidado no histórico): spike, pdr, adr, ddr, idr, epic, arch, design,
    // validation, ux, copy. Manter esta lista alinhada com a prática real do time —
    // o enum estava defasado e quebrava a CI a cada push de commit não-feat/fix.
    "type-enum": [
      2,
      "always",
      [
        // Conventional Commits padrão
        "feat",
        "fix",
        "docs",
        "chore",
        "refactor",
        "perf",
        "test",
        "ci",
        "build",
        "style",
        "revert",
        "wip",
        // Fluxo de decisões e documentos do Turni
        "spike",
        "pdr",
        "adr",
        "ddr",
        "idr",
        "epic",
        "arch",
        "design",
        "validation",
        "ux",
        "copy",
      ],
    ],
    "subject-case": [0],   // permite maiúsculas (útil em PT-BR)
    "body-max-line-length": [0],
  },
};

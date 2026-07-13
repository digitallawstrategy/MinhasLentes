# Direções visuais — Version 2: Apple Quality

Três propostas de paleta para o MinhasLentes, preparadas para decisão antes de aplicar
qualquer uma ao código (issue [#10](https://github.com/digitallawstrategy/MinhasLentes/issues/10)).
As cores semânticas (sucesso/atenção/crítico) permanecem as mesmas nas três opções — só a
marca (primária/secundária) muda.

Comparação visual aplicada aos componentes reais (`StatusCard`, `ReminderCard`, `ActionCard`):
ver o artefato publicado nesta conversa, ou reabrir este documento depois que a decisão for
registrada abaixo.

## Opção A — Apple Health

- Primária: `#2F82FF` · Secundária: `#2FA84F` · Superfície: `#F3F6FA`
- Azul-claro e verde sobre fundos neutros. Aparência clínica e serena.
- Risco: reaproveita quase literalmente o vocabulário do app Saúde da Apple — mais fácil de
  acertar, mais fácil de parecer "mais um app de saúde".

## Opção B — Indigo e violeta

- Primária: `#4F46E5` · Secundária: `#7C4FE0` · Superfície: `#F5F3FC`
- Indigo como cor principal, violeta como destaque. Tecnológico, elegante e pessoal, sem
  perder a sensação de saúde e confiança.
- Risco: indigo/violeta pode ler como "genérico de app de produtividade" se o violeta deixar
  de ser um destaque pontual e virar tão frequente quanto o indigo.

## Opção C — Aqua

- Primária: `#0EA5A0` · Secundária: `#4FD1C8` · Superfície: `#EEFAF8`
- Azul-esverdeado com referência discreta a transparência e hidratação. Leve e limpo — a
  direção mais literal ao tema de lentes de contato.
- Risco: é a paleta mais parecida com apps de meditação/hidratação genéricos.

## Recomendação

Inclinação inicial (do usuário) para a **Opção B**: é a que menos se parece com um
concorrente direto (A copia a Apple, C copia apps de hidratação/meditação) e a que melhor
sustenta um tom de "acompanhante pessoal" em vez de "gerenciador clínico".

## Decisão

Direção aprovada: **Opção B — Indigo e violeta** (commit `c8e3009`).

- Indigo (`AccentColor` colorset): cor principal e de interação — botões primários, links,
  seleção de aba, tint do sistema.
- Violeta (`AppSecondary` colorset): destaque de marca pontual — nunca representa estado
  semântico (sucesso/atenção/crítico).
- Verde, laranja e vermelho (`AppColor.success`/`.warning`/`.critical`): exclusivamente
  estados, nunca usados como cor de marca.
- Fundos e superfícies (`AppColor.surface`/`.surfaceElevated`): neutros e adaptativos, sem
  depender da paleta de marca.

Ambas as cores de marca têm variantes de modo claro, escuro e contraste aumentado definidas
no asset catalog — nenhum valor hexadecimal aparece fora dos dois `.colorset`.

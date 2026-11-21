#!/usr/bin/env ruby
# frozen_string_literal: true

# Regenerates docs/security-audit/audit-security-report.md
# Usage: ruby docs/security-audit/generate_report.rb
#
# The findings below were produced by a manual, read-only audit of the
# wine_words_api (Rails 8.1 + PostgreSQL + devise-jwt + Pundit) codebase,
# mapped from the five categories in issue #23. Each finding is verified
# against real code with exact file:line references. Re-run after fixes;
# delete rows whose exploit no longer reproduces.

require "time"

OUT = File.expand_path("audity-security-report.md", __dir__)   # exact path requested by issue #23
ALIAS = File.expand_path("audit-security-report.md", __dir__)  # corrected spelling (same content)
DATE = Time.now.utc.strftime("%Y-%m-%d")

# severity => palette (from the issue)
PALETTE = {
  "Critical" => "#B91C1C",
  "High" => "#EA580C",
  "Medium" => "#D97706",
  "Low" => "#2563EB",
  "Info" => "#6B7280",
  "Strong" => "#059669"
}.freeze

SEV_EMOJI = {
  "Critical" => "🔴", "High" => "🟠", "Medium" => "🟡",
  "Low" => "🔵", "Info" => "⚪", "Strong" => "🟢"
}.freeze

CATEGORIES = {
  1 => "1. Tenant / Owner Isolation (Banco sem Tranca)",
  2 => "2. Browser-Defined Permission vs Server Enforcement",
  3 => "3. IDOR (Insecure Direct Object Reference)",
  4 => "4. Exposed Secrets (Chaves Expostas)",
  5 => "5. Untreated Inputs / XSS"
}.freeze

# --- Verified findings -------------------------------------------------------
# kind: "finding" or "strong"
FINDINGS = [
  # Category 1 – Tenant/owner isolation
  { kind: "strong", cat: 1, title: "Article & Review feeds are policy-scoped",
    file: "app/controllers/api/v1/articles_controller.rb", line: "24",
    note: "policy_scope(articles) + Article.visible_to scope; drafts only to author/managers." },
  { kind: "strong", cat: 1, title: "Analytics reporting uses a single role-scoped boundary",
    file: "app/services/analytics/scope.rb", line: "69-105",
    note: "Reviewers see own content only; Editors content-scoped; Admins site-wide; out-of-scope detail returns nil → 404." },
  { kind: "strong", cat: 1, title: "Per-user collections scoped to current_user",
    file: "app/controllers/api/v1/notifications_controller.rb", line: "84",
    note: "current_user.notifications.delivered.find(...) and current_user.push_subscriptions.find(...) prevent cross-user reads." },
  { kind: "strong", cat: 1, title: "Trade guest access is token-bound",
    file: "app/controllers/api/v1/trade/messages_controller.rb", line: "39-48",
    note: "Owner (submitter_id) OR valid guest token; uniform 404 otherwise — no ID probing." },
  { kind: "finding", cat: 1, sev: "Info", title: "Isolation is application-layer only (no DB Row-Level Security)",
    file: "db/schema.rb", line: "n/a",
    note: "Single-tenant model (no tenant_id). Isolation depends entirely on Pundit/controllers; a missing authorize in future code silently leaks. Consider RLS or a deny-by-default test harness as defense-in-depth." },

  # Category 2 – frontend vs backend
  { kind: "strong", cat: 2, title: "Server re-checks every role the UI hides",
    file: "app/policies/user_policy.rb", line: "4-14",
    note: "assign_roles/assign_subscription/soft_delete/hard_delete require user&.admin?; create/search/show require catalogue_manager. ERB/React gates are advisory only." },
  { kind: "strong", cat: 2, title: "Server-rendered management forms guard writes",
    file: "app/controllers/wines_controller.rb", line: "7",
    note: "before_action :deny_unless_wine_manager! on new/create/edit/update/destroy; articles controller uses ensure_author!." },
  { kind: "finding", cat: 2, sev: "Info", title: "UI role helpers are duplicated in ERB views",
    file: "app/controllers/articles_controller.rb", line: "144-150",
    note: "can_manage_article? / can_manage_wines? drive button visibility. Controllers enforce the same rules today — keep them in sync; a drift would only hide/show buttons, not grant access." },

  { kind: "finding", cat: 2, sev: "Critical", title: "Unauthenticated catalogue CRUD on server-rendered controllers (no auth at all)",
    file: "app/controllers/wine_profiles_controller.rb", line: "1-43",
    note: "WineProfilesController, TasteParametersController (app/controllers/taste_parameters_controller.rb:1-43), TestParametersController and WineTasteParametersController inherit ActionController::Base with NO before_action, NO RequireLogin and NO authorize — anyone can POST/PATCH/DELETE /wine_profiles, /taste_parameters, /wine_taste_parameters, /test_parameters (config/routes.rb:64,65,101,102). The matching JSON API controllers DO authorize; only the web copies are open." },
  { kind: "finding", cat: 2, sev: "High", title: "API wine_profiles mutations allow any authenticated user",
    file: "app/controllers/api/v1/wine_profiles_controller.rb", line: "29-53",
    note: "create/update/destroy only require the global authenticate_user! (line 13 skips it for read-only actions). There is no WineProfilePolicy and no role guard, so a self-registered Guest/Reader can create, modify or delete wine profiles via /api/v1/wine_profiles (config/routes.rb:220)." },

  # Category 3 – IDOR
  { kind: "strong", cat: 3, title: "Pundit authorize runs after every find",
    file: "app/controllers/api/v1/reviews_controller.rb", line: "244,285,301,317",
    note: "show/create/update/destroy all call authorize @review; set_review scopes through the review relation." },
  { kind: "strong", cat: 3, title: "Image mutations are type-allowlisted and authorized",
    file: "app/controllers/api/v1/images_controller.rb", line: "9-66",
    note: "ALLOWED_TYPES allowlist + authorize @record, :update? before create/destroy/reorder/set_primary." },
  { kind: "strong", cat: 3, title: "Comment edit/delete check ownership/moderation",
    file: "app/controllers/api/v1/comments_controller.rb", line: "60-79",
    note: "permission.can_edit?/can_delete? gate update/destroy." },
  { kind: "finding", cat: 3, sev: "Low", title: "Trade quote lookup ignores the package in the URL",
    file: "app/controllers/api/v1/admin/trade/quotes_controller.rb", line: "79-85",
    note: "set_quote = WinePackageQuote.find(params[:id]) and set_package_for_quote uses @quote.wine_package, so the :package_id segment is not enforced. Reachable only by catalogue managers (ensure_trade_manager!), so impact is low; bind the quote to the package to remove ambiguity." },

  # Category 4 – exposed secrets / credential handling
  { kind: "strong", cat: 4, title: "No secrets are committed; env/key files are ignored",
    file: ".gitignore", line: "1-8",
    note: "/.env* (except .env.example), /config/*.key, scripts/age-keys.txt ignored. `git ls-files` has no master.key; history has no sk_live_/AKIA/PRIVATE KEY." },
  { kind: "strong", cat: 4, title: "Provider secrets come from the environment",
    file: "app/services/billing/providers/stripe.rb", line: "301-310",
    note: "Stripe webhook signature verified with ENV['STRIPE_WEBHOOK_SECRET'] via Stripe::Webhook.construct_event; API key read from ENV only." },
  { kind: "strong", cat: 4, title: "Sensitive params filtered from logs",
    file: "config/initializers/filter_parameter_logging.rb", line: "6-10",
    note: "passw, email, secret, token, message, _key, crypt, salt, certificate, otp, ssn, cvv, cvc filtered." },
  { kind: "finding", cat: 4, sev: "Medium", title: "JWT access tokens effectively never expire",
    file: "config/initializers/devise.rb", line: "321-323",
    note: "jwt.expiration_time = 100.years.to_i. A stolen bearer token stays valid until an explicit sign_out (JwtDenylist) or soft-delete. Set a bounded TTL (e.g. 30-60 min) + refresh or sliding renewal." },
  { kind: "finding", cat: 4, sev: "Medium", title: "No login brute-force protection (no lockable, no auth throttle)",
    file: "config/initializers/rack_attack.rb", line: "10-63",
    note: "Rack::Attack throttles analytics/contact/trade/invitations but NOT /api/v1/auth/sign_in; the User model omits Devise :lockable. Add a per-IP+per-email sign-in throttle and/or :lockable." },
  { kind: "finding", cat: 4, sev: "Low", title: "Commented secret-looking value committed",
    file: "config/initializers/devise.rb", line: "17",
    note: "`# config.secret_key = '3b5ce8...'` (Devise generator placeholder) left in source. Remove it; real key is secret_key_base. Not exploitable as-is (real key unused) but should not ship." },
  { kind: "finding", cat: 4, sev: "Low", title: "Default password fallback in e2e seeds",
    file: "db/seeds/e2e.rb", line: "5",
    note: "ENV.fetch('E2E_USER_PASSWORD', 'Playwright123!'). Guarded by `abort unless Rails.env.e2e?`, so it cannot run in prod; keep the guard and never reuse this value elsewhere." },

  # Category 5 – XSS
  { kind: "strong", cat: 5, title: "Stimulus controllers escape interpolated data",
    file: "app/javascript/controllers/quiz_controller.js", line: "78-92,208-215",
    note: "Every innerHTML interpolation passes through this.escape() (and wine_search_controller.js likewise)." },
  { kind: "strong", cat: 5, title: "Region tree renders via content_tag/link_to (auto-escaped)",
    file: "app/helpers/regions_helper.rb", line: "2-50",
    note: "render_regions_tree builds nodes with content_tag/link_to, so .html_safe on the result wraps already-escaped markup." },
  { kind: "strong", cat: 5, title: "Image uploads validated for type and size",
    file: "app/models/image.rb", line: "9-72",
    note: "ALLOWED_CONTENT_TYPES (jpeg/png/webp/gif) + 10MB cap." },
  { kind: "finding", cat: 5, sev: "Medium", title: "Stored XSS via grape name in wine form",
    file: "app/views/wines/_form.html.erb", line: "151,165-168",
    note: "`raw(...).to_json` inside <script> and `selectedBox.innerHTML = ... + g.name`. A grape name containing </script> or HTML executes in the editor's browser when the wine form loads. Catalogue managers set grape names." },
  { kind: "finding", cat: 5, sev: "Medium", title: "Stored XSS via review title / wine name in article form",
    file: "app/views/articles/_form.html.erb", line: "213,418,433,463",
    note: "span.innerHTML = \"<strong>\" + review.title + … and \"<strong>\" + wine.name. Same pattern in app/views/articles/edit.html.erb:107,127. Reviewer-authored titles execute in other editors' browsers." },
  { kind: "finding", cat: 5, sev: "Medium", title: "Stored XSS via wine name in review form",
    file: "app/views/reviews/_form.html.erb", line: "196",
    note: "done.innerHTML = \"<strong>\" + wine.name + … — wine names are catalogue-manager controlled." },
  { kind: "finding", cat: 5, sev: "Low", title: "CSP allows unsafe-inline and unsafe-eval",
    file: "config/initializers/content_security_policy.rb", line: "12-13",
    note: "script_src includes :unsafe_inline, :unsafe_eval. A nonce is also set (mitigates inline <script>), but unsafe_eval weakens defences; remove once inline handlers are gone." },
  { kind: "finding", cat: 5, sev: "Medium", title: "Public trade submissions skip Turnstile despite the comment",
    file: "app/controllers/api/v1/trade/submissions_controller.rb", line: "6,35-68",
    note: "Comment says Turnstile is enforced; neither controller nor Trade::Submissions::Create verifies it. Only Rack::Attack (10/hour/IP) guards intake. Add Turnstile verification like the contact form." }
].freeze



# --- Rendering helpers -------------------------------------------------------
SEVERITY_ORDER = %w[Critical High Medium Low Info].freeze

def findings(cat: nil)
  s = FINDINGS.select { |f| f[:kind] == "finding" }
  cat ? s.select { |f| f[:cat] == cat } : s
end

def strengths(cat: nil)
  s = FINDINGS.select { |f| f[:kind] == "strong" }
  cat ? s.select { |f| f[:cat] == cat } : s
end

def sev_counts
  SEVERITY_ORDER.to_h { |sev| [sev, findings.count { |f| f[:sev] == sev }] }
end

def cell(text) = text.to_s.gsub("|", "\\|").gsub("\n", " ")

def chip(sev) = "#{SEV_EMOJI[sev]} **#{sev}**"

def cat_counts
  CATEGORIES.keys.to_h { |c| [c, findings(cat: c).size] }
end

def mermaid_donut
  present = SEVERITY_ORDER.select { |sev| findings.count { |f| f[:sev] == sev } > 0 }
  rows = present.map { |sev| %(    "#{sev}" : #{findings.count { |f| f[:sev] == sev }}) }.join("\n")
  vars = present.each_with_index.map { |sev, i| %('pie#{i + 1}':'#{PALETTE[sev]}') }.join(",")
  <<~MERMAID
    ```mermaid
    %%{init: {'theme':'base','themeVariables':{#{vars}}}}%%
    pie showData
        title Findings by severity
    #{rows}
    ```
  MERMAID
end
def render_cover
  total = findings.size
  <<~MD
    # Relatório de Auditoria de Segurança (Security Audit Report)

    **Projeto:** `romalopes/wine_words_api`
    **Issue:** #23 — Code Revision
    **Data:** #{DATE}
    **Escopo:** API Rails (`wine_words_api`): controllers, policies, models, services, initializers, views, deploy config e histórico git — leitura apenas (nenhum arquivo de produção alterado).

    **Metodologia (stack detectada):** aplicação **Ruby 3.4 / Rails 8.1** monolítica: **PostgreSQL** via **ActiveRecord**, autenticação **Devise + devise-jwt** (Bearer JWT), autorização **Pundit**, frontend **Hotwire (Turbo + Stimulus) + views ERB server-rendered** (o SPA React vive em outro repositório), deploy **Docker + Kamal + Render**, **rack-attack**, **Sentry**. Cada uma das 5 categorias da issue foi mapeada para o equivalente desta stack:

    | Categoria (issue) | Equivalente nesta stack | Como foi verificado |
    |---|---|---|
    | 1. Banco sem tranca | `policy_scope` + `authorize` + filtros de visibilidade (sem RLS) | Varredura de todos os controllers, policies e `Analytics::Scope` |
    | 2. Permissão no navegador | Helpers ERB/React de papel vs `before_action`/Pundit no servidor | Cruzamento de cada gate de UI com o guard do endpoint |
    | 3. IDOR | `find`/`find_by` + `authorize` + scoping por `current_user` | Leitura de todos os `set_*` e ações `show/update/destroy` |
    | 4. Chaves expostas | `.env*`, `master.key`, credentials, ENV, histórico git | `git ls-files`/`git log -S`, grep de padrões de chave |
    | 5. Inputs sem tratamento | `raw`/`html_safe`/`innerHTML` em ERB + Stimulus, templates de e-mail | Grep de sinks e leitura do contexto de cada ocorrência |

    > Total de achados verificados: **#{total}** (apenas problemas reais). Pontos fortes verificados são listados separadamente para provar a cobertura.
  MD
end

def render_exec_summary
  counts = sev_counts
  total = findings.size
  sev_rows = SEVERITY_ORDER.map do |sev|
    "| #{chip(sev)} | #{counts[sev]} |"
  end.join("\n")
  <<~MD
    ## 1. Resumo executivo

    | Severidade | Qtd |
    |---|---:|
    #{sev_rows}
    | **Total** | **#{total}** |

    **Legenda de cores:** 🔴 Crítica `#B91C1C` · 🟠 Alta `#EA580C` · 🟡 Média `#D97706` · 🔵 Baixa `#2563EB` · ⚪ Informativa · 🟢 Ponto forte `#059669`.

    ### Achados por severidade (rosca)

    #{mermaid_donut}

    ### Achados por categoria (barras)

    #{mermaid_bars}

    | Categoria | Achados |
    |---|---:|
    #{CATEGORIES.keys.map { |c| "| #{CATEGORIES[c]} | #{cat_counts[c]} |" }.join("\n")}

    **Leitura rápida:** há **1 achado crítico e 1 alto**, ambos de **controle de acesso**: quatro controllers server-rendered expõem CRUD de catálogo **sem autenticação**, e `/api/v1/wine_profiles` aceita escrita de **qualquer usuário logado** (sem papel). O segundo risco central é **XSS armazenado** nos formulários ERB (categoria 5); em seguida **JWT de 100 anos** e **login sem rate-limit** (categoria 4).
  MD
end

def render_strengths
  rows = strengths.map do |f|
    "| #{chip('Strong')} | `#{cell(f[:file])}:#{f[:line]}` | #{cell(f[:title])} — #{cell(f[:note])} |"
  end.join("\n")
  <<~MD
    ## 2. Pontos fortes (verificados)

    | | Evidência | O que está protegido |
    |---|---|---|
    #{rows}
  MD
end

def render_weaknesses
  <<~MD
    ## 3. Pontos fracos (riscos centrais)

    1. **CRÍTICO — CRUD de catálogo sem autenticação:** `WineProfilesController`, `TasteParametersController`, `TestParametersController` e `WineTasteParametersController` herdam de `ActionController::Base` sem `RequireLogin`/`before_action`, expondo `POST/PATCH/DELETE` desses recursos a qualquer visitante. As versões JSON equivalentes em `Api::V1::*` estão protegidas — o buraco é só nas rotas web.
    2. **ALTO — `/api/v1/wine_profiles` sem papel:** escrita liberada a qualquer usuário autenticado (não existe `WineProfilePolicy`).
    3. **XSS armazenado nos forms ERB** (`wines/_form`, `articles/_form`, `articles/edit`, `reviews/_form`): `innerHTML`/`raw` com nomes de uva/vinho/título de review sem escape.
    4. **Sessão sem expiração + login sem limite:** JWT válido por 100 anos e nenhum throttle/`lockable` em `/api/v1/auth/sign_in`.
    5. **Turnstile ausente no intake de trade**, apesar do comentário em contrário.
  MD
end

def render_category(cat)
  fs = findings(cat: cat)
  ss = strengths(cat: cat)
  title = CATEGORIES[cat]
  if fs.empty?
    detail = "_Nenhum problema verificado nesta categoria._\n"
  else
    rows = fs.map do |f|
      "| #{chip(f[:sev])} | `#{cell(f[:file])}:#{f[:line]}` | **#{cell(f[:title])}** — #{cell(f[:note])} |"
    end.join("\n")
    detail = <<~TBL
      | Severidade | Arquivo:linha | Descrição |
      |---|---|---|
      #{rows}
    TBL
  end
  strong_note =
    if ss.empty?
      ""
    else
      "**Pontos fortes verificados:** " + ss.map { |s| "#{s[:title]} (`#{s[:file]}:#{s[:line]}`)" }.join("; ") + ".\n"
    end
  <<~MD
    ### #{title}

    #{detail}
    #{strong_note}
  MD
end


def mermaid_bars
  labels = CATEGORIES.transform_values { |v| v.split('. ', 2).last }
  lines = CATEGORIES.keys.map do |c|
    short = c.to_s + " " + (labels[c] || "").gsub('"', '')
    %(    "#{short}" : #{cat_counts[c]})
  end.join("\n")
  <<~MERMAID
    ```mermaid
    %%{init: {'theme':'base','themeVariables':{'xyChart':{'plotColorPalette':'#{PALETTE['High']}'}}}}%%
    xychart-beta
        title "Findings per category"
        x-axis ["1 Isolation","2 Permissions","3 IDOR","4 Secrets","5 XSS"]
        y-axis "Count" 0 --> #{[cat_counts.values.max + 1, 3].max}
        bar [#{CATEGORIES.keys.map { |c| cat_counts[c] }.join(', ')}]
    ```
  MERMAID
end

def render_recommendations
  <<~MD
    ## 4. Recomendações priorizadas

    **P0 — bloquear imediatamente**
    0. **Fechar o CRUD web não autenticado:** incluir `RequireLogin` + guard de papel (`deny_unless_wine_manager!`/`catalogue_manager?`) em `WineProfilesController`, `TasteParametersController`, `TestParametersController` e `WineTasteParametersController`; adicionar `authorize` + criar `WineProfilePolicy` em `Api::V1::WineProfilesController`.

    **P1 — corrigir nesta sprint**
    1. **Escape nos forms ERB (XSS):** trocar `innerHTML = "... " + valor` por `textContent`/`createElement`, e trocar `raw(...).to_json` por `json_escape(...)` dentro do `<script>` (`wines/_form`, `articles/_form`, `articles/edit`, `reviews/_form`).
    2. **Expiração de JWT:** reduzir `jwt.expiration_time` para 30–60 min (com refresh/sliding) ou impor TTL absoluto.
    3. **Rate limit + lockout no login:** adicionar throttle `auth/sign_in` por IP e por e-mail no `rack_attack.rb` e/ou `:lockable` no Devise.

    **P2 — próximo ciclo**
    4. **Turnstile no intake de trade** (igual ao form de contato) e alinhar o comentário com o código.
    5. **CSP:** remover `:unsafe_inline`/`:unsafe_eval` após eliminar handlers inline; manter o nonce.
    6. **Trade quote:** amarrar `set_quote` ao `params[:package_id]`.

    **P3 — hardening contínuo**
    7. Remover o `secret_key` comentado em `devise.rb` e o default de senha em `db/seeds/e2e.rb` (manter guard).
    8. Adicionar um teste deny-by-default que garanta `authorize`/`policy_scope` em todo controller novo (defesa para a ausência de RLS).
    9. Avaliar Row-Level Security no PostgreSQL como segunda barreira de isolamento.
  MD
end

def issue_block(n, f)
  slug = { 1 => "isolation", 2 => "permissions", 3 => "idor", 4 => "secrets", 5 => "xss" }[f[:cat]]
  <<~MD
    --- ISSUE #{n} ---
    **Título:** [Segurança] #{f[:title]}
    **Labels sugeridas:** security, sev-#{f[:sev].downcase}, #{slug}

    ### Descrição
    #{f[:note]}

    ### Evidência
    `#{f[:file]}:#{f[:line]}`

    ### Impacto
    #{f[:sev]} — ver resumo executivo para a exploração detalhada desta categoria.

    ### Sugestão de correção
    Ver "Recomendações priorizadas" (P1/P2/P3) no relatório.

    ### Critérios de aceite
    - [ ] O sink/vetor apontado em `#{f[:file]}:#{f[:line]}` foi corrigido.
    - [ ] Teste automatizado que reproduz o problema passa a falhar sem a correção.
    - [ ] Nenhum novo achado com a mesma classe foi introduzido na revisão de PR.
    --- FIM ISSUE #{n} ---
  MD
end

def render_issues
  fs = findings.reject { |f| f[:sev] == "Info" }
  body = fs.each_with_index.map { |f, i| issue_block(i + 1, f) }.join("\n")
  <<~MD
    ## 5. ISSUES PARA O GITHUB

    Cada bloco abaixo está pronto para copiar e colar como issue. Total: #{fs.size}.

    #{body}
  MD
end

def build
  parts = []
  parts << render_cover
  parts << render_exec_summary
  parts << render_strengths
  parts << render_weaknesses
  parts << "## 4. Achados detalhados por categoria\n"
  CATEGORIES.keys.each { |c| parts << render_category(c) }
  parts << render_recommendations
  parts << render_issues
  parts << render_appendix
  parts.join("\n\n")
end

def render_appendix
  <<~'MD'
    ---

    ### Apêndice — regenerar e renderizar (A4)

    ```bash
    # Regenera este relatório a partir dos achados versionados no script:
    ruby docs/security-audit/generate_report.rb

    # (opcional) PDF A4 com gráficos (pandoc + weasyprint + mermaid-cli):
    pandoc audity-security-report.md -o audit.pdf --pdf-engine=weasyprint -V geometry:margin=2cm
    ```

    _Nenhum binário de PDF (pandoc/wkhtmltopdf/weasyprint) estava instalado no ambiente da auditoria; o `.md` é a fonte canônica e renderiza no GitHub (incluindo Mermaid `pie`/`xychart`)._
  MD
end


doc = build
File.write(OUT, doc)
File.write(ALIAS, doc)
puts "Wrote #{OUT} and #{ALIAS} (#{findings.size} findings, #{strengths.size} strong points)"


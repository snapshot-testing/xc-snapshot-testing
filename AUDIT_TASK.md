# AUDIT_TASK — checklist de correções

Origem: [AUDIT.md](AUDIT.md) (base `main` @ `5dc7a44`). Cada item referencia o ID do relatório, que traz arquivo:linha,
cenário e correção sugerida. Marque `[x]` ao concluir e anote o commit/PR; não apague itens feitos, para manter o histórico.

Legenda de estado: `[ ]` pendente · `[~]` em andamento · `[x]` concluído (com commit).

## Alto

- [x] **A1** — `ImageBytes.serialize` gravava arquivo de 0 bytes quando o PNG não podia ser gerado — `35ae019`
  - Corrigido na origem: lança `BytesSerializationError`. Regressão em `ImageSerializationTests`.
  - Decisão: **não** recusar conteúdo vazio em `SnapshotFileEngine.perform` (snapshots de texto/dados vazios são legítimos).
- [ ] **A2** — Identidade do snapshot depende da ordem de execução e ignora a classe/suíte (`TestingSession`)
- [ ] **A3** — `Array.sequence()` engole erros e bloqueia sem timeout (`.func(into:)` de `CaseIterable`)

## Médio

- [ ] **M1** — Conversões `TimeInterval → inteiro` sem validação (timeout fracionário falha na hora; traps em ∞/NaN/negativo; `delay` em 11 pontos)
- [ ] **M2** — Limpeza (root VC, `detachChild`, `dispose`) só roda no caminho de sucesso
- [ ] **M3** — Diff de texto por LCS super-linear e recursivo (183 s com 4000 linhas repetidas)
- [ ] **M4** — `WindowPool.acquire` escolhe o lease mais disputado; comparador inválido; `maxConcurrentTests` sem clamp
- [ ] **M5** — Esperas sem limite com `timeout` zero (`WKWebView.waitLoadingState`, `snapshotSignal.wait()`)
- [ ] **M6** — Kernel Metal retorna sem erro e pode dar falso "passou"
- [ ] **M7** — `.json` de `Any` derruba o processo em objeto inválido (NSException)
- [ ] **M8** — Seletores privados com `as!` e retain extra em `DescriptorMethod`
- [ ] **M9** — `DiffTool` recebe URLs `file://` em vez de caminhos absolutos; literal sem aspas
- [ ] **M10** — Credenciais (`Authorization`, `Cookie`) gravadas em snapshots `.raw`/`.curl`
- [ ] **M11** — Diretórios criados a cada asserção, inclusive em modo leitura / checkout somente leitura
- [ ] **M12** — Ponteiros de `[UInt8]` escapam da chamada em `CGImage.context(with:)`
- [ ] **M13** — `SyncContinuation` não é resume-once; resume duplo derruba o processo

## Baixo

- [ ] **L1** — `SnapshotView.add`: `leadingAnchor` repetido, sem `trailingAnchor`
- [ ] **L2** — `SizeListener.delegate` com `willSet` que não faz nada
- [ ] **L3a** — Hunk final só de contexto no diff
- [ ] **L3b** — CRLF não é dividido em linhas; igualdade por equivalência canônica de Unicode
- [ ] **L4** — Sanitização de nomes com perda (colisões) e `platform` sem sanitizar
- [ ] **L5** — `curl`: force unwraps de `url`/`httpMethod`, escape incompleto; CSV sem escape
- [ ] **L6** — Performance diversa (`CIContext` por comparação, buffers grandes, `TestCounter`, defaults recalculados, comparação no main thread)
- [ ] **L7** — `performOnMainThread` com `DispatchQueue.main.sync` (risco de deadlock)
- [ ] **L8** — Código morto (`CGContextCreateBitmapContext`, `snapshotDateFormatter`, notificação sem observador, `storing(in:)`)
- [ ] **L9** — Force unwraps em CGPath/CALayer (path vazio, layer de tamanho zero)
- [ ] **L10** — `NumberFormatter` sem locale fixo em `elementsDescription`
- [ ] **L11** — `precondition` em entrada de API pública (`DeviceOrientation`, `maxConcurrentTests`)
- [ ] **L12** — Ambiente capturado na criação da estratégia (traits) vs. na execução (`imageFormat`)
- [ ] **L13** — Snapshots de hierarquia contêm a view auxiliar `UIViewSizeListener`
- [ ] **L14** — `Task.timeout` não propaga o cancelamento do pai

## Ordem sugerida

1. A1 ✔ → A2 → A3
2. M1, M2, M4, M5, M13 (travamentos e crashes em uso normal)
3. M3, M6, M7, M9, M10, M11
4. Itens baixos em lote

## Como trabalhar cada item

1. Reproduzir com um teste que falha (em `Tests/XCSnapshotTestingCoreTests`).
2. Corrigir na origem; conferir que o teste novo falha sem a correção.
3. `swift test --filter XCSnapshotTestingCoreTests` no macOS (a CI cobre a perna iOS).
4. Marcar o item aqui com o hash do commit.

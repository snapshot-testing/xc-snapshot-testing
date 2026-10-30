# Auditoria — xc-snapshot-testing (`Sources/**`)

Base: `main` @ `5dc7a44`. Auditoria **somente leitura**; nenhum código-fonte foi alterado.
Escopo: integridade, performance, segurança e disponibilidade dos ~108 arquivos Swift de `Sources/`.

Metodologia: leitura integral do núcleo (Tester, Assert, Serialization, Diff, Environment, Sync/Async, WindowPool, SnapshotUIController, extensões de imagem/CI) e leitura dirigida das definições de estratégia por plataforma (as `Snapshot+*.swift` seguem o mesmo padrão). Dois achados foram **reproduzidos** num script isolado (`Difference.swift` + `DiffHunk.swift` compilados com `swiftc -O`): o item M3 e os itens L3a/L3b. Os demais foram verificados por leitura do código; o que depende de comportamento de UIKit/CoreImage em runtime está marcado como "não reproduzido".

Resultado: **nenhum item crítico** (nada permite execução remota, escrita fora do diretório de snapshots a partir de entrada não confiável, nem corrompe arquivos fora do próprio snapshot). Há **3 itens altos**, 13 médios e vários baixos. Os falsos positivos descartados estão no final.

---

## ALTO

### A1 — `ImageBytes.serialize` grava um arquivo de 0 bytes quando o PNG não pode ser gerado
- **Onde:** [ImageBytes.swift:102-106](Sources/XCSnapshotTesting/Serialization/Defaults/ImageBytes.swift:102) (consumido em [SnapshotTester.swift:263](Sources/XCSnapshotTesting/Tester/SnapshotTester.swift:263) e [SnapshotFileEngine.swift:92](Sources/XCSnapshotTesting/Tester/SnapshotFileEngine.swift:92)).
- **Problema:** `guard let data = rawValue.encodedPNG(...) else { return }` sai sem escrever nada e sem lançar erro. O container continua com `Data()`, e `SnapshotTester.record` grava esse `Data()` vazio com `.atomic`.
- **Cenário:** uma imagem sem bitmap de suporte (`UIImage()` do fallback `renderer.uiImage ?? UIImage()` em [Snapshot+View.swift](Sources/XCSnapshotTesting/Methods/UI/Snapshot+View.swift) no watchOS, imagem de tamanho zero, `UIImage` apoiada em `CIImage`) faz `pngData()` devolver `nil`. Em `record: .all`/`.failed` isso **sobrescreve uma referência válida por um arquivo vazio**. Em `.missing` cria um arquivo vazio. Nas execuções seguintes `contentExists` é `true`, `loadSnapshot` lança `BytesSerializationError` e o teste falha com erro até alguém apagar o arquivo à mão.
- **Correção:** lançar `BytesSerializationError` quando `encodedPNG` devolver `nil`. Como defesa em profundidade, `SnapshotFileEngine.perform` pode recusar `contents.isEmpty`.

### A2 — Identidade do snapshot depende da ordem de execução e ignora a classe de teste
- **Onde:** [TestingSession.swift:71-96](Sources/XCSnapshotTesting/Assert/TestingSession.swift:71) (chave `TestLocation` = `fileID + filePath + function`) e [SnapshotTester.swift:310-341](Sources/XCSnapshotTesting/Tester/SnapshotTester.swift:310).
- **Problema:** o sufixo `.N` do arquivo é a **ordem de chegada** da posição `(line, column)` no registro de processo. A chave não inclui a classe/suíte, e o diretório é só o nome do arquivo (`__Snapshots__/<Arquivo>/<função>.<N>.png`).
- **Cenários:**
  1. Duas classes no mesmo arquivo com `testExample()`: A recebe `.1` e B recebe `.2` quando rodam juntas. Rodando só B (`-only-testing:B/testExample`, filtro, ordem aleatória, paralelo) B recebe `.1` e **compara com a referência de A**: falso negativo, ou, em `.all`, sobrescreve o snapshot de A.
  2. Um `assert` condicional (`if cond { assert(L10) }; assert(L20)`) numera L20 como `.1` quando a condição é falsa e como `.2` quando é verdadeira, trocando as referências entre execuções.
  3. Swift Testing parametrizado: todos os argumentos compartilham o mesmo `#function` e rodam concorrentemente no mesmo arquivo (corrida de escrita/comparação), a menos que o usuário passe `name:`.
- **Correção:** derivar o sufixo de algo estável, como a posição `line:column` ou um hash do call site, em vez da ordem de chegada. Incluir o tipo/suíte na chave e no caminho. Documentar que `named:` é obrigatório em testes parametrizados (ou usar o argumento do caso).

### A3 — `Array.sequence()` engole erros e bloqueia sem timeout (afeta `.func(into:)` de `CaseIterable`)
- **Onde:** [Sync.swift:380-395](Sources/XCSnapshotTesting/Sync.swift:380) e [Snapshot+CaseIterable.swift](Sources/XCSnapshotTesting/Methods/Snapshot+CaseIterable.swift).
- **Problema:** (a) `if case .success(let output) = result { append }` descarta silenciosamente os `.failure`. O CSV resultante simplesmente **não tem a linha** do caso que falhou, e o snapshot "passa" ou é gravado incompleto. (b) `dispatchGroup.wait()` sem timeout roda dentro do `producer`, ou seja, **antes** do `dispatchGroup.wait(timeout:)` do `SnapshotTester`. O `timeout:` de 5 s do `assert` não protege nada: se um item nunca chamar o callback, o teste trava para sempre. Se o callback precisar da main queue e a main estiver bloqueada neste `wait`, há deadlock.
- **Cenário:** `assert(of: { Color.red($0) }, as: .func(into: .description))`, onde um dos casos lança erro, produz um snapshot sem aquele caso e nenhuma falha.
- **Correção:** propagar o primeiro `.failure` via `continuation.resume(throwing:)`. Trocar o `wait()` por composição assíncrona, ou `wait(timeout:)`. Preservar a ordem das saídas.

---

## MÉDIO

### M1 — Conversões `TimeInterval → inteiro` sem validação (timeouts falsos e crashes)
- [Task+Extension.swift:36](Sources/XCSnapshotTesting/Extensions/Task+Extension.swift:36): `UInt64(timeout) * 1_000_000_000` **trunca a fração**. `timeout: 0.5` vira `sleep(0)`: o timeout vence imediatamente e o `assert` falha com "Exceeded timeout of 0.5 seconds". `1.9` vira 1 s. Em `.infinity`, `.nan`, negativo ou `> ~1.8e10` há *trap* (conversão/overflow) em API pública (`Task.timeout`).
- [SnapshotTester.swift:108](Sources/XCSnapshotTesting/Tester/SnapshotTester.swift:108): `.nanoseconds(Int(timeout * 1_000_000_000))` dá *trap* com `.infinity`/NaN/`> 9.2e9`.
- `UInt64(delay * 1_000_000_000)` em 11 pontos ([Snapshot+View.swift:76,162](Sources/XCSnapshotTesting/Methods/UI/Snapshot+View.swift:76), [Snapshot+UIView.swift:82,165](Sources/XCSnapshotTesting/Methods/UI/Snapshot+UIView.swift:82), [Snapshot+UIViewController.swift:82,247](Sources/XCSnapshotTesting/Methods/UI/Snapshot+UIViewController.swift:82), [Snapshot+UIApplication.swift:78](Sources/XCSnapshotTesting/Methods/UI/Snapshot+UIApplication.swift:78), [Snapshot+NSView.swift:72,148](Sources/XCSnapshotTesting/Methods/UI/Snapshot+NSView.swift:72), [Snapshot+NSViewController.swift:72,147](Sources/XCSnapshotTesting/Methods/UI/Snapshot+NSViewController.swift:72)) e [WKWebView+Extension.swift:11](Sources/XCSnapshotTesting/Extensions/WKWebView+Extension.swift:11): `delay` negativo ou NaN derruba o processo de teste.
- **Correção:** uma função única `nanoseconds(_ t: TimeInterval) -> UInt64` que faça `max(0, t)`, trate NaN/∞ e satura em `UInt64.max`, usando `(t * 1e9).rounded(.up)`. Preferir `Duration`.

### M2 — Limpeza (restaurar root VC, `detachChild`, esconder janela) só roda no caminho de sucesso
- **Onde:** [ViewOperationPayload.swift:64](Sources/XCSnapshotTesting/Methods/UI/Core/ViewOperationPayload.swift:64) (`snapshot`) e `:94` (`descriptor`); encadeado por `.snapshot(executor)`/`.descriptor(...)` em todas as estratégias de view.
- **Problema:** se qualquer etapa entre `connectToWindow` e o fim lançar (`prepare` com erro, `RenderingError`, `CancellationError` do timeout em `snapshotSignal.wait()`, falha no `executor`), `removeRootViewController`/`detachChild`/`dispose` não executam. `withWindow` ainda chama `release(window)` (esconde a janela e destrava o lease), mas o `SnapshotUIController` continua como `rootViewController` da janela pooled e retém a view sob teste.
- **Cenário:** um teste que estoura o timeout deixa um controller órfão na janela. O próximo teste a reutiliza, `switchRoot` devolve esse controller como `previousRootViewController`, e ele é restaurado como root (vazamento + contaminação de estado entre testes). O `UIViewSizeListener` injetado na view do usuário ([SizeListener.swift:87](Sources/XCSnapshotTesting/Methods/UI/Core/SizeListener.swift:87)) também nunca é removido, e vira uma duplicata se a mesma instância for reutilizada.
- **Correção:** mover a limpeza para um `defer`/`do-catch` em torno da operação (ou fazê-la em `withWindow`, no `release`). Não reproduzido em dispositivo.

### M3 — Diff de texto por LCS é super-linear e recursivo (travamento em falhas com textos grandes)
- **Onde:** [Difference.swift:27-105](Sources/XCSnapshotTesting/Diff/Difference.swift:27).
- **Problema:** para cada elemento de `other` itera todos os índices iguais do primeiro array e reconstrói um `Dictionary` (`currentOverlap`) a cada passo. Isso é O(n·m·k) com alocações. A recursão tem profundidade proporcional ao número de blocos, e há cópias de `prefix/suffix` em cada nível.
- **Medição (reproduzida, `swiftc -O`):** 4000 linhas idênticas (`"}"`) com uma alteração a cada 7 linhas levaram **183 s**. O diff só roda quando o teste já falhou, mas faz uma falha de snapshot virar um travamento de minutos em CI (dumps JSON/hierarquia com muitas linhas repetidas).
- **Correção:** Myers O(ND) ou `CollectionDifference` da stdlib (`difference(from:)`), com limite de tamanho e fallback "N linhas diferentes".

### M4 — `WindowPool.acquire` escolhe o lease *mais* disputado, e o comparador não é uma ordenação válida
- **Onde:** [WindowPool.swift:47-51](Sources/XCSnapshotTesting/Methods/UI/WindowPool/WindowPool.swift:47): `sorted(by: { $0.pendingTasks >= $1.pendingTasks }).first!`.
- **Problema:** `>=` ordena de forma decrescente, então escolhe o lease com **mais** esperando. O balanceamento fica invertido: o teste entra na fila do mais ocupado enquanto outra janela está livre. Como o `timeout` do `assert` cobre a espera pelo lease, isso gera timeouts espúrios. O `>=` também viola a estrita ordenação fraca exigida por `sorted(by:)`. Além disso, `maxConcurrentTests` vem sem validação de `TestingSystem.environment` ([MaxConcurrentTestsEnvironmentKey.swift:11](Sources/XCSnapshotTesting/Environment/Defaults/MaxConcurrentTestsEnvironmentKey.swift:11)). O valor 0 faz `leases[0..<0]...first!` dar *trap*, e um negativo quebra o range. A precondition só existe no *setter*.
- **Correção:** `leases.prefix(max).min(by: { $0.pendingTasks < $1.pendingTasks })`. Clamp `max(1, n)` no getter padrão.

### M5 — Esperas sem limite quando o `timeout` padrão é zero
- `assert` assíncrono tem `timeout: .zero` (sem timeout) por padrão ([Assert.swift:54](Sources/XCSnapshotTesting/Assert/Assert.swift:54)). Dois pontos podem nunca terminar:
  - [WKWebView+Extension.swift:9-13](Sources/XCSnapshotTesting/Extensions/WKWebView+Extension.swift:9): `repeat { sleep } while isLoading` sem limite. Uma página que nunca termina de carregar (rede travada, long-polling) trava o teste. Com `tolerance: 0` vira *busy loop* no MainActor. Cada WKWebView adiciona ≥2,5 s sequenciais (`waitLoadingStateIfNeeded` percorre as subviews em série).
  - [SnapshotUIController.swift:203 e 279](Sources/XCSnapshotTesting/Methods/UI/Core/SnapshotUIController.swift:203): `try await snapshotSignal.wait()` só é liberado por `viewDidLayoutSubviews`. Se o layout não ocorrer (view sem janela / sem invalidação), não há saída. Não reproduzido, depende do UIKit.
- **Correção:** teto interno (ex.: `webViewTolerance × N` iterações) e timeout padrão finito, ou aplicar um timeout default no `snapshot()`.

### M6 — Kernel Metal retorna sem erro e pode produzir um falso "passou"
- **Onde:** [CIImage+Extension.swift:213-222](Sources/XCSnapshotTesting/Extensions/CIImage+Extension.swift:213) (`ThresholdImageProcessorKernel.process`).
- **Problema:** se `metalCommandBuffer`, `metalTexture` ou o argumento forem `nil`, o `guard ... else { return }` sai sem lançar. O Core Image então usa a textura de saída não escrita (lixo/zeros). `measuringWithMetal` lê a média ≈ 0, calcula `actualPixelPrecision = 1` e a comparação perceptual **passa** sem ter comparado nada. O fallback de CPU só é acionado se `applyingThreshold` lançar.
- **Correção:** `throw` nos ramos de falha para que `measuringWithMetal` devolva `nil` e caia no caminho de CPU. Não reproduzido em hardware.

### M7 — `.json` (de `Any`) derruba o processo em objetos inválidos
- **Onde:** [Snapshot+Any.swift:46-57](Sources/XCSnapshotTesting/Methods/Snapshot+Any.swift:46).
- **Problema:** `JSONSerialization.data(withJSONObject:)` com objeto inválido (`NaN`, `Date`, chave não-String, tipo customizado) lança **NSException**, que o `try` do Swift não captura. Isso é um crash, não um erro de teste.
- **Correção:** `guard JSONSerialization.isValidJSONObject(data)` e lançar um erro Swift.

### M8 — Seletores privados com `as!` e retain extra
- **Onde:** [SnapshotUIController.swift:248-263](Sources/XCSnapshotTesting/Methods/UI/Core/SnapshotUIController.swift:248).
- **Problema:** `_printHierarchy`, `recursiveDescription` e `_subtreeDescription` são chamados via `perform(Selector)` sem `responds(to:)`. Uma versão de SO que renomeie/remova o seletor causa *unrecognized selector*; um retorno `nil` ou de tipo diferente falha no `as! String`. Além disso, `.retain().takeUnretainedValue()` adiciona um retain nunca balanceado (vazamento por chamada). `perform` já devolve o objeto não retido.
- **Correção:** checar `responds(to:)`, usar `as? String` e lançar um erro. Remover o `.retain()`.

### M9 — `DiffTool` recebe URLs `file://` em vez dos caminhos absolutos documentados
- **Onde:** [SnapshotTester.swift:232-236](Sources/XCSnapshotTesting/Tester/SnapshotTester.swift:232) passa `snapshotURL.absoluteString`; a documentação de [DiffTool.swift](Sources/XCSnapshotTesting/Diff/DiffTool.swift) promete "absolute file paths".
- **Problema:** `ksdiff "file:///Users/x/My%20Dir/a.png" "file:///..."` (caracteres percent-encoded, esquema `file://`) não é o que a ferramenta espera, e quebra para diretórios com espaço ou acentos. O inicializador por string literal ainda concatena `"\(value) \($0) \($1)"` sem aspas, o que quebra com espaços e é injeção de shell se o comando for copiado de um caminho com `$`/`` ` ``/`;`.
- **Correção:** passar `url.path` e escapar para shell nos presets/literal.

### M10 — Vazamento de credenciais para snapshots versionados (`.raw` e `.curl`)
- **Onde:** [Snapshot+URLRequest.swift:37-39 e 96-117](Sources/XCSnapshotTesting/Methods/Snapshot+URLRequest.swift:37).
- **Problema:** todos os headers (incl. `Authorization`, `Cookie`, `X-Api-Key`) e o body são gravados em texto puro no arquivo de snapshot, que costuma ir para o git. Não há opção de redação.
- **Correção:** parâmetro `redacting: Set<String>` (padrão: `Authorization`, `Cookie`, `Proxy-Authorization`, `X-Api-Key`) e/ou aviso na documentação.

### M11 — Diretórios criados a cada asserção, inclusive em modo leitura
- **Onde:** [SnapshotFileEngine.swift:35 e 60](Sources/XCSnapshotTesting/Tester/SnapshotFileEngine.swift:35).
- **Problema:** `sourceURL(for:)` faz `createDirectory(...withIntermediateDirectories: true)` em todo `assert`, mesmo com `record: .never` e com referência existente (I/O redundante, mais efeitos colaterais na árvore de fontes). Em checkouts somente leitura (sandbox/Bazel/CI com volume ro) o `createDirectory` lança **antes** da comparação, e o teste falha por erro de I/O em vez de comparar.
- **Correção:** criar o diretório apenas imediatamente antes de gravar (no `perform(.write)`).

### M12 — Ponteiros de `[UInt8]` escapam da chamada em `CGImage.context(with:)`
- **Onde:** [UIImage+Extension.swift:171-172, 191-192, 276-285](Sources/XCSnapshotTesting/Extensions/UIImage+Extension.swift:171) e [CGImage+Extension.swift:10-18](Sources/XCSnapshotTesting/Extensions/CGImage+Extension.swift:10).
- **Problema:** `&oldBytes` (array → `UnsafeMutableRawPointer`) só vale durante a chamada, mas o `CGContext` guarda o ponteiro e depois `oldContext.data`/`makeImage()` são lidos. É comportamento indefinido pela regra de Swift. Hoje funciona porque o buffer do array não é realocado, mas o compilador não garante isso.
- **Correção:** `bytes.withUnsafeMutableBytes { ... }` cobrindo todo o uso do contexto, ou deixar o `CGContext` alocar o buffer (`data: nil`) e comparar via `context.data`.

### M13 — `SyncContinuation` não é "resume-once"; resume duplo derruba o processo
- **Onde:** [Sync.swift:6-43](Sources/XCSnapshotTesting/Sync.swift:6), [Sync.swift:62-70](Sources/XCSnapshotTesting/Sync.swift:62), [SnapshotTester.swift:101-105](Sources/XCSnapshotTesting/Tester/SnapshotTester.swift:101).
- **Problema:** `Sync.init(block)` captura `catch { continuation.resume(throwing:) }`. Um `block` que chama `continuation.resume(...)` e **depois** lança resume duas vezes. No `SnapshotTester` isso vira `dispatchGroup.leave()` desbalanceado (crash do libdispatch). Na ponte assíncrona ([Sync.swift:114](Sources/XCSnapshotTesting/Sync.swift:114)) é `UnsafeContinuation` resumida duas vezes (comportamento indefinido).
- **Correção:** guarda atômica de uso único dentro de `SyncContinuation`.

---

## BAIXO

- **L1 — `SnapshotView.add` repete `leadingAnchor` e não define `trailingAnchor`** ([SnapshotView.swift:84-86](Sources/XCSnapshotTesting/Methods/UI/Core/SnapshotView.swift:84)). Provável typo (a 4ª constraint deveria ser `trailingAnchor`). O container fica com a largura subespecificada, e o layout só funciona porque nada recorta. Corrigir.
- **L2 — `SizeListener.delegate` com `willSet { updateSize(size) }`** ([SizeListener.swift:28](Sources/XCSnapshotTesting/Methods/UI/Core/SizeListener.swift:28)) usa o `size` atual, que é igual ao que `updateSize` guarda, então o `guard` sai e nada acontece (código morto, provavelmente queria `newValue`/notificar o delegate novo).
- **L3a — Hunk final só de contexto** (reproduzido): quando o último bloco comum tem mais de 8 linhas, `groupping` devolve um hunk extra sem nenhuma mudança (`@@ −27,4 +27,4 @@` com 4 linhas inalteradas) ([Difference.swift:188](Sources/XCSnapshotTesting/Diff/Difference.swift:188)).
- **L3b — CRLF não é dividido em linhas** (reproduzido): `split(separator: "\n")` em `String` compara `Character`, e `"\r\n"` é um único grafema. Arquivos CRLF viram "uma linha" no diff ([StringDiffAttachmentGenerator.swift:51-55](Sources/XCSnapshotTesting/Diff/Defaults/StringDiffAttachmentGenerator.swift:51)). Além disso, `reference.rawValue != diffable.rawValue` usa equivalência canônica de Unicode (NFC/NFD), então textos diferentes em bytes mas canonicamente iguais "passam" sem regravar.
- **L4 — Nomes de snapshot sanitizados com perda e `platform` sem sanitizar.** `sanitizingPathComponent` remove `\ / : * ? " < > |` e controles, então `"a:b"`, `"a/b"` e `"ab"` colidem no mesmo arquivo ([String+Extension.swift:19-34](Sources/XCSnapshotTesting/Extensions/String+Extension.swift:19)). `tester.platform` (de `withTestingEnvironment(platform:)`/trait do Swift Testing) é anexado como componente de caminho sem sanitização ([SnapshotFileEngine.swift:123-129](Sources/XCSnapshotTesting/Tester/SnapshotFileEngine.swift:123)): `"../.."` sai do diretório de snapshots. O valor vem do desenvolvedor, não de entrada não confiável, por isso a severidade baixa. Mesmo assim, aplicar a sanitização.
- **L5 — `curl`/CSV:** `request.url!`, `.sortingQueryItems()!` e `httpMethod!` ([Snapshot+URLRequest.swift:91,123](Sources/XCSnapshotTesting/Methods/Snapshot+URLRequest.swift:91)) viram *trap* com `URL` ausente/inválido (via `URLRequest.url = nil`). Só escapa `"`, não `$`, `` ` `` nem `\`, então o comando gravado não é seguro de colar no shell. A CSV de `CaseIterable` não escapa aspas/quebras de linha ([Snapshot+CaseIterable.swift:53](Sources/XCSnapshotTesting/Methods/Snapshot+CaseIterable.swift:53)).
- **L6 — Performance diversa:**
  - `CIContext` novo a cada comparação perceptual ([CIImage+Extension.swift:26](Sources/XCSnapshotTesting/Extensions/CIImage+Extension.swift:26)); inicialização de Metal por chamada.
  - `compare` aloca 2–3 buffers do tamanho da imagem (`oldBytes`, `newerBytes`, `diffBytes`) mais cópias de `CGContext`. Em snapshots de rolagem longa (milhares de pontos × scale 3) o pico passa de centenas de MB.
  - `TestCounter` copia o array inteiro por chamada (`var items = _registry[key, default: []]; items.append`) ([TestingSession.swift:84-93](Sources/XCSnapshotTesting/Assert/TestingSession.swift:84)).
  - Chaves de ambiente (`platform`, `platformVersion`, `maxConcurrentTests`, `recordMode`) recalculam o `defaultValue` a cada acesso, incluindo `DispatchQueue.main.sync` para `UIDevice`.
  - `ImageDiffAttachmentGenerator` executa toda a comparação (byte a byte + CI) no main thread ([ImageDiffAttachmentGenerator.swift:80](Sources/XCSnapshotTesting/Diff/Defaults/ImageDiffAttachmentGenerator.swift:80)).
- **L7 — `performOnMainThread` usa `DispatchQueue.main.sync`** ([Sync.swift:343-352](Sources/XCSnapshotTesting/Sync.swift:343)): deadlock se a main thread estiver bloqueada esperando a thread chamadora (por exemplo `assert` síncrono chamado de uma queue em que a main fez `sync`). Em `async` bloqueia uma thread do pool cooperativo.
- **L8 — Código morto/sem consumidor:** `CGContextCreateBitmapContext` ([SnapshotUIController.swift:439](Sources/XCSnapshotTesting/Methods/UI/Core/SnapshotUIController.swift:439)), `snapshotDateFormatter` ([Snapshot+Any.swift:61](Sources/XCSnapshotTesting/Methods/Snapshot+Any.swift:61)), `XCTestBundleDidFinishNotification` é postada em [CleanCounterBetweenTestCases.swift:23](Sources/XCSnapshotTesting/Assert/CleanCounterBetweenTestCases.swift:23) mas nada neste pacote a observa (o `TestingSession` nunca é zerado entre bundles), `NSLayoutConstraint.storing(in:)`.
- **L9 — Force unwraps em CGPath/CALayer (macOS):** `path.copy(using:)!` e `NSGraphicsContext.current!` ([Snapshot+CGPath.swift:51](Sources/XCSnapshotTesting/Methods/UI/Snapshot+CGPath.swift:51), [Snapshot+CALayer.swift:41](Sources/XCSnapshotTesting/Methods/UI/Snapshot+CALayer.swift:41)) quebram para path vazio (`boundingBoxOfPath == .null`) ou layer de tamanho zero. Em iOS, `UIGraphicsImageRenderer(bounds: .null)` também falha.
- **L10 — `NumberFormatter` sem locale fixo** em `elementsDescription` ([Snapshot+CGPath.swift:172-176](Sources/XCSnapshotTesting/Methods/UI/Snapshot+CGPath.swift:172)): dígitos/agrupamento dependem do locale da máquina, e o snapshot varia entre dev e CI. Fixar `en_US_POSIX`.
- **L11 — `precondition` em entrada de API pública:** `DeviceOrientation.portrait(ratio)`/`.landscape(ratio)` com `ratio != .extended` aborta o processo em todos os layouts de iPhone ([LayoutConfiguration.swift:750,760](Sources/XCSnapshotTesting/Methods/UI/Core/LayoutConfiguration.swift:750)); `maxConcurrentTests < 1` ([MaxConcurrentTestsEnvironmentKey.swift:41](Sources/XCSnapshotTesting/Environment/Defaults/MaxConcurrentTestsEnvironmentKey.swift:41)). Preferir erro/clamp.
- **L12 — Ambiente capturado na criação da estratégia:** `LayoutConfiguration.resolve(..., with: SnapshotEnvironment.current.traits.merging(traits))` roda quando `.image(...)` é construído, não quando executa. Uma estratégia guardada em `static let` ignora `withTestingEnvironment { $0.traits = ... }` posterior, enquanto `imageFormat` é lido na execução (inconsistente).
- **L13 — Snapshots de hierarquia contêm a view auxiliar injetada** (`UIViewSizeListener`), de modo que renomear a classe quebra todas as referências de `recursiveDescription`/`hierarchy`.
- **L14 — `Task.timeout` não propaga o cancelamento do pai** ([Task+Extension.swift:11-56](Sources/XCSnapshotTesting/Extensions/Task+Extension.swift:11)): as `Task {}` internas são não estruturadas. Cancelar o teste não cancela `closure`; só o timeout cancela. Após o timeout vencer, o executor pode seguir rodando (e segurando o lease da janela) até terminar.

---

## Falsos positivos descartados (verificados no código)

- **Path traversal por `name`/`function`:** `sanitizingPathComponent` remove `/` e `\`, e o nome é concatenado (`função + "." + nome`), nunca usado como componente isolado. Não há escape do diretório de snapshots.
- **Escrita não atômica de snapshots:** `Data.write(to:options:.atomic)` ([SnapshotFileEngine.swift:92](Sources/XCSnapshotTesting/Tester/SnapshotFileEngine.swift:92)) é atômica.
- **Dupla retomada em `Task.timeout`:** `TimeoutCompletion.resume` é protegido por lock e retorna `false` se já retomado.
- **`AsyncLock` e cancelamento no `WindowLease`:** o `AsyncLock` é "cancellation transparent" (a aquisição nunca é abortada), então `unlock()` não solta um lock alheio. `release` roda também no `catch` de `withWindow`.
- **`OBJC_ASSOCIATION_ASSIGN` em `windowLease`:** o `WindowPool` mantém os `WindowLease` fortemente em `leases` (nunca removidos); o ponteiro não fica pendente enquanto o pool vive.
- **`request.httpMethod!` / `headers[field]!`:** `URLRequest` devolve `"GET"` por padrão e a chave vem de `headers.keys`; seguros na prática (só `url!` é frágil, ver L5).
- **`.first!` em `WindowPool.acquire`:** seguro enquanto `maxConcurrentTests ≥ 1` e há leases (a entrada fora desse limite é o item M4).
- **Race em `UnsafeSyncDiffable`/`BytesContainer.State`:** protegidos por `NSLock`.

## Ordem sugerida de correção
1. A1 (perda de dados), A2 (identidade do snapshot), A3.
2. M1, M2, M4, M5, M13 (travamentos e crashes em uso normal).
3. M3, M6, M7, M9, M10, M11.
4. Itens baixos em lote.

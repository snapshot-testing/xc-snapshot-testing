# A1 — `ImageBytes.serialize` must not write an empty file

Origem: item **A1** de [AUDIT.md](AUDIT.md) (severidade alta, integridade/perda de dados).

## Problema

`ImageBytes.serialize(to:)` ([ImageBytes.swift:102](Sources/XCSnapshotTesting/Serialization/Defaults/ImageBytes.swift:102)) faz
`guard let data = rawValue.encodedPNG(...) else { return }`. Quando o PNG não pode ser gerado
(`UIImage()` vazio, imagem de tamanho zero, `UIImage` apoiada em `CIImage`, `NSBitmapImageRep` nula no macOS),
o container fica com `Data()` e `SnapshotTester.record` grava um arquivo de **0 bytes**:

- `record: .all` / `.failed` sobrescreve uma referência válida por um arquivo vazio.
- `record: .missing` cria um arquivo vazio.
- Nas execuções seguintes `contentExists` é `true`, `loadSnapshot` lança `BytesSerializationError` e o teste
  falha por erro até alguém apagar o arquivo à mão.

## Decisão de escopo

- **Corrigir na origem:** `ImageBytes.serialize` lança `BytesSerializationError` em vez de retornar em silêncio.
- **Não** recusar `contents.isEmpty` em `SnapshotFileEngine.perform`, como o AUDIT sugeria como defesa em profundidade:
  `StringBytes("")` e `DataBytes(Data())` são snapshots legítimos de 0 bytes, e uma checagem genérica os quebraria.
- O erro lançado em `serialize` acontece antes de `engine.perform`, então nada é gravado e a referência existente
  fica intacta.

## Critérios de aceite

1. `DataSerialization().serialize(ImageBytes(rawValue: <imagem sem PNG>))` lança `BytesSerializationError`.
2. Uma asserção de imagem sem PNG com `record: .all`, `.failed` e `.missing` propaga o erro, **não** cria arquivo
   e **não** altera a referência existente.
3. Snapshots de texto/dados vazios continuam sendo gravados normalmente.
4. Imagens válidas continuam passando pelo round-trip (testes existentes de `ImageSerializationTests`).
5. A suíte `XCSnapshotTestingCoreTests` passa.

## Arquivos

- `Sources/XCSnapshotTesting/Serialization/Defaults/ImageBytes.swift` — correção.
- `Tests/XCSnapshotTestingCoreTests/Image/ImageSerializationTests.swift` — teste unitário do serializador.
- `Tests/XCSnapshotTestingCoreTests/Tester/SnapshotTesterTests.swift` — teste de ponta a ponta (referência intacta).

## Fora de escopo

Demais itens do AUDIT (A2, A3, M*). Sem commit até o usuário pedir.

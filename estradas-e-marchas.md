# Estradas e marchas

A pista tem sete solos, nesta ordem. O buff e o debuff não dependem da marcha. Dependem da velocidade do carro em km/h.

O número é a eficiência da força no chão. **0%** repassa a força inteira. Acima disso, mais força chega ao chão. Abaixo disso, menos força chega e o carro perde velocidade. Não existe freio forçado.

A partir de **160 km/h** o carro perde velocidade cada vez mais rápido, em qualquer estrada. Em **250 km/h** ele explode e aparece a tela de morte.

## Ordem na pista

| Ordem | Estrada | Trecho |
| --- | --- | --- |
| 1 | Asfalto preto | Do início até 21600 |
| 2 | Barro | 21600 até 30600 |
| 3 | Grama verde | 30600 até 42600 |
| 4 | Areia | 42600 até 53600 |
| 5 | Gelo | 53600 até 65600 |
| 6 | Vulcão | 65600 até 76600 |
| 7 | Montanha | 76600 até o fim |

## Asfalto preto

| Velocidade | Bônus |
| --- | --- |
| 0 a 60 km/h | +20% |
| 60 a 80 km/h | sobe de +20% até +40% |
| 80 a 160 km/h | +40% |

O chão agarra pouco e o carro rola fácil. O gelo e o barro continuam com o atrito próprio deles.

## Barro

| Velocidade | Bônus |
| --- | --- |
| 0 a 50 km/h | +10% |
| 50 a 160 km/h | -80% |

Em baixa velocidade a força passa um pouco melhor. Passou de 50 km/h, quase nada chega ao chão e o carro perde velocidade. O barro continua agarrando a roda.

## Grama verde

| Velocidade | Bônus |
| --- | --- |
| 0 a 20 km/h | 0% |
| 20 a 60 km/h | +40% |
| 60 a 80 km/h | desce de +40% até -40% |
| 80 a 160 km/h | -40% |

## Areia

| Velocidade | Bônus |
| --- | --- |
| 0 a 30 km/h | 0% |
| 30 a 60 km/h | +20% |
| acima de 60 km/h | 0% |

## Gelo

| Velocidade | Bônus |
| --- | --- |
| 0 a 30 km/h | +40% |
| 30 a 40 km/h | +10% |
| 40 a 160 km/h | -60% |

O gelo continua escorregando e limitando o giro. O debuff de velocidade é aparte disso.

## Vulcão

Igual ao asfalto preto.

| Velocidade | Bônus |
| --- | --- |
| 0 a 60 km/h | +20% |
| 60 a 80 km/h | sobe de +20% até +40% |
| 80 a 160 km/h | +40% |

Os vulcões empurram o carro para cima. Isso não depende da velocidade.

## Montanha

Igual à grama verde.

| Velocidade | Bônus |
| --- | --- |
| 0 a 20 km/h | 0% |
| 20 a 60 km/h | +40% |
| 60 a 80 km/h | desce de +40% até -40% |
| 80 a 160 km/h | -40% |

## Acima de 160 km/h

Em qualquer solo, passar de 160 km/h faz o carro perder velocidade. A perda cresce de forma exponencial até 250 km/h. Ao chegar em 250 km/h, o carro explode e usa a mesma tela de morte de uma batida.

## Tamanho da roda

O `tamanho` 1 é a roda normal. Vale a média das rodas que estão no carro.

- Perto do tamanho 2, a roda maior dá um pouco mais de velocidade.
- O peso cresce com o tamanho e divide a força que vai ao chão. O chassi também fica mais pesado e mais estável.
- No tamanho 5 o carro mal anda.
- No tamanho 10 ou mais a força de tração é zero e o carro não sai do lugar.

A marcha não muda o bônus da estrada. Ela limita até onde o motor consegue empurrar:

| Marcha | Acelera até | Torque |
| --- | --- | --- |
| 1ª | 15 km/h | a mais forte, ladeira íngreme |
| 2ª | 30 km/h | alto |
| 3ª | 50 km/h | sobe a ladeira comum |
| 4ª | 80 km/h | menor |
| 5ª | 150 km/h | ainda empurra no plano |

A 1ª puxa forte e para de acelerar em 15 km/h. Subir a marcha não tira a velocidade que o carro já tem: o giro cai e a marcha nova volta a empurrar. A 5ª chega perto de 150 km/h. No manual, W ou seta para cima sobe a marcha e S ou seta para baixo desce. No automático, a troca acontece sozinha perto do corte de cada marcha. O freio do motor só age com o acelerador solto. Acima de 160 km/h entra a perda de velocidade, e em 250 km/h o carro explode. A ré usa a força e o corte da 1ª.

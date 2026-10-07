extends Node

var velocidade := 2000.0
var cor_carro := "vermelho"
var roda_atras := {
	"presente": true,
	"tamanho": 1.0,
	"distancia": 1.0,
}
var roda_frente := {
	"presente": true,
	"tamanho": 1.0,
	"distancia": 1.0,
}
var marcha_inicial := 5
var marcha := "Manual"
var motorista := "ryan.png"

func acelerar(tempo: float) -> float:
	return velocidade * tempo

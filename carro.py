class Carro:
	velocidade = 1000
	cor_carro = "vermelho"
	roda_atras = {
		"presente": True,
		"tamanho": 1.0,
		"distancia": 1.0,
	}
	roda_frente = {
		"presente": True,
		"tamanho": 1.0,
		"distancia": 1.0,
	}
	marcha_inicial = 1
	marcha = "Manual"
	motorista = "ryan.png"

	def acelerar(self, tempo):
		return self.velocidade * tempo

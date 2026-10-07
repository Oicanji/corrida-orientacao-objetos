class_name Corrida
extends RefCounted

const Z0 := 21600.0
const Z1 := 30600.0
const Z2 := 42600.0
const Z3 := 53600.0
const Z4 := 65600.0
const Z5 := 76600.0
const Z6 := 94600.0
const SPAWN_X := 0.0
const MARGEM_NIVEL := 3600.0
const VEL_MULT := 4.0
const EMPUXO_FATOR := 16.0
const KMH_FATOR := 0.16 / VEL_MULT
const KMH_TETO := 160.0
const KMH_MORTE := 250.0
const MASSA_CHASSI := 7.5
const MASSA_RODA := 0.85
const PX_POR_KM := 22500.0 * VEL_MULT
const VEL_MORTE := 5500.0 * VEL_MULT
const VEL_JUNTA_RIGIDA := 420.0 * VEL_MULT
const ZOOM_VEL := 1500.0 * VEL_MULT
const CABECA_PX := 100.0
const ARQ_CARRO_ALUNO := "user://carro_aluno.py"
const ARQ_CARRO_RES := "res://carro.py"
const ARQ_JOGAR := "user://corrida_jogar.flag"
const PASTA_MOTORISTA := "user://motoristas/"
const CICLO_CEU_SEG := 240.0

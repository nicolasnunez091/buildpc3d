extends Node
class_name Recomendador

func validate_compatibility(cpu: Dictionary, motherboard: Dictionary, ram: Dictionary, gpu: Dictionary, psu: Dictionary, chassis: Dictionary, max_budget: int) -> Dictionary:
	var errors: Array = []
	var is_compatible: bool = true
	
	var cpu_socket: String = cpu.get("socket", "")
	var mobo_socket: String = motherboard.get("socket", "")
	if cpu_socket != "" and mobo_socket != "" and cpu_socket != mobo_socket:
		is_compatible = false
		errors.append("El zócalo del procesador no coincide con la tarjeta madre.")

	var total_tdp: int = cpu.get("tdp_vatios", 0) + gpu.get("tdp_vatios", 0) + 50
	var psu_wattage: int = psu.get("tdp_vatios", 0)
	if psu_wattage > 0 and total_tdp > psu_wattage:
		is_compatible = false
		errors.append("La fuente de poder no soporta el consumo estimado.")

	var total_cost: int = cpu.get("precio", 0) + motherboard.get("precio", 0) + ram.get("precio", 0) + gpu.get("precio", 0) + psu.get("precio", 0) + chassis.get("precio", 0)
	var remaining_budget: int = max_budget - total_cost

	if remaining_budget < 0:
		is_compatible = false
		errors.append("El costo total supera el presupuesto máximo.")

	return {
		"is_compatible": is_compatible,
		"total_cost": total_cost,
		"remaining_budget": remaining_budget,
		"errors": errors
	}

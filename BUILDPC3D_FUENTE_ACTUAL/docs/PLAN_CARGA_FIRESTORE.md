# Plan propuesto: carga inicial Firestore

**Destino:** proyecto `buildpc3d`, base `(default)`. **Estado: carga inicial
autorizada y confirmada.** Antes de la carga se verificó administrativamente
que los 43 documentos no existían; después se comprobó que todos coinciden con
el plan. El listado siguiente conserva la evidencia del plan autorizado.

Se propone crear exactamente los 42 documentos siguientes y `meta/catalog`
con `version: 4`. Cada documento de producto llevará todos los campos de su
registro correspondiente en `godot/data/catalog.json` (nombre, precio COP,
procedencia del precio, modelo 3D y atributos técnicos).

## procesadores (8)

```text
procesadores/cpu_amd_ryzen_5_5600g
procesadores/cpu_amd_ryzen_5_5600
procesadores/cpu_amd_ryzen_7_5700x
procesadores/cpu_amd_ryzen_5_7600
procesadores/cpu_amd_ryzen_7_7800x3d
procesadores/cpu_intel_core_i3_12100f
procesadores/cpu_intel_core_i5_12400f
procesadores/cpu_intel_core_i7_14700k
```

## tarjetas_madre (8)

```text
tarjetas_madre/motherboard_gigabyte_a520m_s2h
tarjetas_madre/motherboard_asus_prime_b550m_a_wifi_ii
tarjetas_madre/motherboard_msi_mag_b550_tomahawk
tarjetas_madre/motherboard_asrock_a620m_hdv_m_2
tarjetas_madre/motherboard_msi_pro_b650m_p
tarjetas_madre/motherboard_gigabyte_b650_gaming_x_ax
tarjetas_madre/motherboard_asus_prime_b660m_a_d4
tarjetas_madre/motherboard_gigabyte_b760m_ds3h_ax_d4
```

## memorias_ram (8)

```text
memorias_ram/ram_kingston_fury_beast_8gb_ddr4_2666mhz
memorias_ram/ram_kingston_fury_beast_16gb_2x8_ddr4_3200mhz
memorias_ram/ram_corsair_vengeance_rgb_pro_16gb_2x8_ddr4_3600mhz
memorias_ram/ram_kingston_fury_beast_32gb_2x16_ddr4_3200mhz
memorias_ram/ram_kingston_fury_beast_16gb_2x8_ddr5_5200mhz
memorias_ram/ram_corsair_vengeance_32gb_2x16_ddr5_5600mhz
memorias_ram/ram_teamgroup_t_force_delta_rgb_32gb_2x16_ddr5_6000mhz
memorias_ram/ram_kingston_fury_renegade_rgb_32gb_2x16_ddr5_6400mhz
```

## tarjetas_video (8)

```text
tarjetas_video/gpu_nvidia_gt_1030_2gb
tarjetas_video/gpu_nvidia_gtx_1650_4gb
tarjetas_video/gpu_amd_radeon_rx_6600_8gb
tarjetas_video/gpu_amd_radeon_rx_7600_8gb
tarjetas_video/gpu_nvidia_rtx_3060_12gb
tarjetas_video/gpu_nvidia_rtx_4060_8gb
tarjetas_video/gpu_nvidia_rtx_4070_super_12gb
tarjetas_video/gpu_amd_radeon_rx_7800_xt_16gb
```

## fuentes_poder (5)

```text
fuentes_poder/psu_thermaltake_smart_500w_80_white
fuentes_poder/psu_corsair_cv550_550w_80_bronze
fuentes_poder/psu_msi_mag_a650bn_650w_80_bronze
fuentes_poder/psu_corsair_rm750e_750w_80_gold_atx_3_0
fuentes_poder/psu_msi_mag_a850gl_850w_80_gold_atx_3_0
```

## chasis (5)

```text
chasis/case_chasis_iceberg_basic_matx
chasis/case_chasis_aerocool_cs_107_matx_mesh
chasis/case_chasis_corsair_4000d_airflow_mid_tower
chasis/case_chasis_nzxt_h5_flow_rgb_mid_tower
chasis/case_chasis_lian_li_lancool_216_mesh
```

## Versión y seguridad

```text
meta/catalog  { "version": 4 }
```

Son **43 creaciones** en un único lote atómico. El script usa `create`: si
cualquiera de esos documentos ya existe, el lote falla y no sobrescribe ninguno.
No borra documentos ni colecciones ajenas. Las escrituras del SDK Admin eluden
las reglas cliente y requieren credenciales administrativas locales. Las reglas
publicadas deben comprobarse en Firebase Console; todavía no se ha probado una
escritura denegada en el proyecto real. Los precios son referenciales.

Huella SHA-256 del destino y contenido completo de este plan:

```text
68bffce93569ff23abaa50c3d4786e9831513d77c4c84d8f0aa17844623539e1
```

El cargador exige esa huella junto con la confirmación del proyecto al ejecutar.
Si cambia el catálogo, la versión o el destino, genera y revisa otro plan antes
de autorizarlo; no reutilices una autorización anterior.

El cargador vuelve a leer los 43 documentos antes de escribir. Los reintentos
son limitados y, ante un resultado incierto, se vuelve a comprobar todo el
plan antes de volver a enviar un lote. Si hay coincidencia total no se vuelve a
escribir; ante un estado parcial o diferente, se detiene.

El plan puede regenerarse sin red ni credenciales con:

```powershell
py firebase\seed_firestore.py --project-id buildpc3d
```

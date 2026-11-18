# Precios y limitaciones de compatibilidad del MVP

Fecha de consulta parcial: 16 de noviembre de 2026.

El archivo del usuario incluye una cifra `precio` por modelo, pero NO una fecha ni
una tienda que permita darla como vigente. Este MVP tiene 42 piezas:

- Los precios marcados `referencia_del_archivo_sin_verificar` se conservaron del
  archivo del usuario y **NO son precios actuales confirmados**.
- Los precios marcados `oferta_web_consultada_2026_11_16` son precios observados
  en páginas comerciales durante la consulta y pueden cambiar o estar agotados.
- Cada pieza contiene `price_source_url` cuando había oferta encontrada.

Ejemplos consultados:
- AMD Ryzen 5 5600G: $699.000 COP (PC Masters Bogotá).
  https://pcmastersbogota.com.co/tienda/?filter_category=pre-armados%2Cfuentes-de-poder%2Ctarjetas-graficas%2Cchasis%2Cprocesadores
- AMD Ryzen 7 7800X3D: $1.699.000 COP (PC Masters Bogotá).
  https://pcmastersbogota.com.co/tienda/?filter_category=board%2Cprocesadores%2Cchasis%2Cmonitores
- Chasis Corsair 4000D Airflow: $495.000 COP (PC Masters Bogotá; aparecía agotado).
  https://pcmastersbogota.com.co/tienda/?filter_category=pre-armados%2Cfuentes-de-poder%2Ctarjetas-graficas%2Cchasis%2Cprocesadores
- MSI MAG A650BN 650W 80+ Bronze: $318.885 COP (resultado de producto en mercado colombiano; comprobar presentación/stock).

## Precisión técnica y seguridad

Los datos básicos de CPU, placa, memoria, GPU, PSU y chasis provienen de la lista.
Los atributos extra requeridos para el recomendador (formato de placa, longitud de
GPU, espacio máximo de chasis, núcleos, VRAM) fueron añadidos a un nivel de MVP.
**Las longitudes de GPU no pueden ser precisas sin el SKU exacto de la marca
ensambladora; no deben utilizarse como garantía de compatibilidad de compra.**

Las dimensiones máximas de chasis que están en `max_gpu_mm` también se deben validar
contra fichas técnicas oficiales. La potencia requerida por una CPU puede superar
su TDP nominal. No se comprueba en el MVP la BIOS, conectores de PSU, refrigeración,
ranuras, cantidad de módulos, alimentación EPS, almacenamiento y altura de disipador.

El PDF académico original exige únicamente seis categorías; el archivo del usuario
incluye almacenamiento y refrigeración, que se podrán incorporar en la siguiente fase.

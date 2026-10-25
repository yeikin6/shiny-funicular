--!strict
-- Tipos compartidos entre servidor y cliente.

export type RarityId = "Comun" | "Rara" | "Epica" | "Legendaria" | "Mitica"

-- Mutaciones de tormenta: se apilan multiplicando, pero cada una se aplica una sola vez.
export type MutationId = "Lluvia" | "Rayos" | "Suerte" | "Volcan" | "LluviaEstrellas"

-- Rasgo celestial: solo lo traen las estrellas del evento; ninguna tormenta lo da.
export type CelestialId = "Nocturna" | "Lunar" | "Solar" | "Eclipse"

export type MutationDef = {
	id: MutationId,
	displayName: string,
	multiplier: number,
	weight: number, -- probabilidad relativa de que la tormenta sea de este tipo
	colorHex: string,
}

export type CelestialDef = {
	id: CelestialId,
	displayName: string,
	multiplier: number,
	weight: number,
	colorHex: string,
}

export type RarityDef = {
	id: RarityId,
	displayName: string,
	weight: number, -- peso relativo de caída
	baseRate: number, -- Polvo/s a nivel 0 y 0 rebirths
	carrySpeed: number, -- multiplicador de WalkSpeed al cargarla
	kg: number, -- peso; por ahora solo se muestra, la mochila llega en v0.3
	size: number, -- diámetro en studs
	minRadius: number, -- las raras caen más lejos del centro del cráter
	maxRadius: number,
	colorHex: string,
}

-- Lo que viaja con una estrella cuando se carga, se suelta o se roba.
export type StarInfo = {
	rarity: RarityId,
	mutations: { MutationId },
	celestial: CelestialId?,
}

-- Una estrella colocada en un pedestal. placedAt es os.time() menos la edad que ya traía.
export type StarData = {
	rarity: RarityId,
	mutations: { MutationId },
	celestial: CelestialId?,
	placedAt: number,
	stored: number, -- Polvo sin cobrar en este pedestal
}

export type PlayerData = {
	version: number,
	dust: number,
	runEarned: number, -- Polvo ganado desde el último rebirth (desempate del leaderboard)
	rebirths: number,
	unlockedSlots: number,
	slots: { [string]: StarData }, -- clave "1".."8": diccionario para que el JSON no tenga huecos
	lastSeen: number,
}

return {}

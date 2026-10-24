--!strict
-- Tipos compartidos entre servidor y cliente.

export type RarityId = "Comun" | "Rara" | "Epica" | "Legendaria" | "Mitica"

export type RarityDef = {
	id: RarityId,
	displayName: string,
	weight: number, -- peso relativo de caída
	baseRate: number, -- Polvo/s a nivel 0 y 0 rebirths
	carrySpeed: number, -- multiplicador de WalkSpeed al cargarla
	size: number, -- diámetro en studs
	minRadius: number, -- las raras caen más lejos del centro del cráter
	maxRadius: number,
	colorHex: string,
}

-- Una estrella colocada en un pedestal. placedAt es os.time() menos la edad que ya traía.
export type StarData = {
	rarity: RarityId,
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

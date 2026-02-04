import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export const shortAddress = (address?: string): string => {
  if (!address) return ''
  return `${address?.slice(0, 5)}...${address?.slice(37)}`
}

export const resolveAvatar = (address?: string, size?: string | number) => {
  if (!address) return
  return `https://cdn.stamp.fyi/avatar/${address}${size ? `?s=${size}` : ''}`
}

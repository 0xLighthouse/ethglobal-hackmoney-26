'use client'

import React from 'react'

import { usePrivy } from '@privy-io/react-auth'
import { Button } from './ui/button'
import { resolveAvatar, shortAddress } from '@/lib/utils'
import { useAppStore } from '@/stores/app'

export const ConnectButton: React.FC = () => {
  const { login, logout: privyLogout, authenticated, ready, user } = usePrivy()
  const { logout } = useAppStore()

  const handleLogout = async () => {
    try {
      // Logout our store
      logout()
      // Then logout our Privy auth session
      await privyLogout()
    } catch (error) {
      console.error('Error during logout:', error)
      // TODO: handle error
    }
  }

  if (!ready) {
    return (
      <div className="animate-pulse">
        <div className="h-10 bg-neutral-200 dark:bg-neutral-700 rounded-md w-24" />
      </div>
    )
  }

  if (!authenticated) {
    return (
      <div className="flex items-center gap-2">
        <Button onClick={login} variant="default" size="default">
          Connect Wallet
        </Button>
      </div>
    )
  }

  const walletAddress = user?.wallet?.address
  const avatarUrl = walletAddress ? resolveAvatar(walletAddress, 32) : undefined

  return (
    <div className="flex items-center gap-3 p-2 rounded-lg bg-neutral-50 dark:bg-neutral-800/50">
      <div className="flex items-center gap-2">
        {avatarUrl && (
          <img
            src={avatarUrl}
            alt="User avatar"
            className="w-8 h-8 rounded-full bg-neutral-200 dark:bg-neutral-700"
            onError={(e) => {
              e.currentTarget.style.display = 'none'
            }}
          />
        )}
        <div className="flex flex-col">
          <span className="text-sm font-medium text-neutral-900 dark:text-neutral-100">
            {shortAddress(walletAddress)}
          </span>
          <span className="text-xs text-neutral-500 dark:text-neutral-400">
            Connected
          </span>
        </div>
      </div>
      <Button onClick={handleLogout} variant="outline" size="sm">
        Disconnect
      </Button>
    </div>
  )
}

// A KV namespace in memory, shaped like the DATABASE binding the Worker gets.
export function memoryKV(): KVNamespace & { data: Map<string, string> } {
  const data = new Map<string, string>()
  return {
    data,
    get: async (key: string) => data.get(key) ?? null,
    put: async (key: string, value: string) => {
      data.set(key, value)
    },
    delete: async (key: string) => {
      data.delete(key)
    },
  } as unknown as KVNamespace & { data: Map<string, string> }
}

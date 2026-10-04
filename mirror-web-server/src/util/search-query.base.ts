import { FilterQuery } from 'mongoose'

export abstract class SearchQuery<T> {
  public abstract fields: string[]

  public getSearchFilter(searchQuery: string): FilterQuery<T> {
    const normalized = typeof searchQuery === 'string' ? searchQuery.slice(0, 128) : ''
    const escaped = normalized.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\  public getSearchFilter(searchQuery: string): FilterQuery<T> {
    return {
      $or: this.fields.map((key) => ({ [key]: new RegExp(searchQuery, 'i') }))
    } as FilterQuery<T>
  }')
    return {
      $or: this.fields.map((key) => ({ [key]: new RegExp(escaped, 'i') }))
    } as FilterQuery<T>
  }
}

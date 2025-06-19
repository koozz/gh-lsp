// This is a test file for Biome configuration
import { describe, it, expect } from 'vitest';
import { Biome } from '../src/biome.js';
describe('Biome Configuration', () => {
  it('should create a Biome instance with default values', () => {
    const biome = new Biome();
    expect(biome).toBeInstanceOf(Biome);
    expect(biome.name).toBe('Default Biome');
    expect(biome.temperature).toBe(20);
    expect(biome.humidity).toBe(50);
  });

  it('should allow setting custom values', () => {
    const biome = new Biome('Tropical Rainforest', 30, 80);
    expect(biome.name).toBe('Tropical Rainforest');
    expect(biome.temperature).toBe(30);
    expect(biome.humidity).toBe(80);
  });
}
);

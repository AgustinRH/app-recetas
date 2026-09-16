import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
  Unique,
} from 'typeorm';
import { User } from './user.entity';
import { Ingredient } from './ingredient.entity';

@Entity('pantry_items')
@Unique(['userId', 'ingredientId'])
export class PantryItem {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  userId: string;

  @Column()
  ingredientId: string;

  @Column({ type: 'float', default: 1 })
  quantity: number;

  @Column({ default: 'ud' })
  unit: string;

  @Column({ type: 'varchar', nullable: true })
  expiresAt: string | null;

  @ManyToOne(() => User, (u) => u.pantry, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: User;

  @ManyToOne(() => Ingredient, (i) => i.pantryItems, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'ingredientId' })
  ingredient: Ingredient;
}

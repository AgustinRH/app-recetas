import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import {
  IsBoolean,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
} from 'class-validator';
import { CurrentUser } from '../common/current-user.decorator';
import { User } from '../entities/user.entity';
import { ShoppingService } from './shopping.service';

class AddShoppingDto {
  @IsUUID()
  ingredientId: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  quantity?: number;

  @IsOptional()
  @IsString()
  unit?: string;
}

class PatchShoppingDto {
  @IsOptional()
  @IsBoolean()
  checked?: boolean;

  @IsOptional()
  @IsNumber()
  @Min(0)
  quantity?: number;

  @IsOptional()
  @IsString()
  unit?: string;
}

@Controller('shopping')
export class ShoppingController {
  constructor(private readonly shopping: ShoppingService) {}

  @Get()
  list(@CurrentUser() user: User) {
    return this.shopping.list(user.id);
  }

  @Post()
  add(@CurrentUser() user: User, @Body() body: AddShoppingDto) {
    return this.shopping.add(user.id, body);
  }

  @Post('from-recipe/:recipeId')
  fromRecipe(@CurrentUser() user: User, @Param('recipeId') recipeId: string) {
    return this.shopping.addMissingFromRecipe(user.id, recipeId);
  }

  /** Pasa a la despensa todo lo marcado como comprado. */
  @Post('checkout')
  checkout(@CurrentUser() user: User) {
    return this.shopping.checkout(user.id);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: User,
    @Param('id') id: string,
    @Body() body: PatchShoppingDto,
  ) {
    return this.shopping.update(user.id, id, body);
  }

  /** Vacía la lista (o sólo lo marcado, con ?checked=true). */
  @Delete()
  clear(@CurrentUser() user: User, @Query('checked') checked?: string) {
    return this.shopping.clear(user.id, checked === 'true');
  }

  @Delete(':id')
  remove(@CurrentUser() user: User, @Param('id') id: string) {
    return this.shopping.remove(user.id, id);
  }
}

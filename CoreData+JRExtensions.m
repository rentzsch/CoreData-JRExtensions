/*******************************************************************************
	CoreData+JRExtensions.m
		Copyright (c) 2006-2011 Jonathan 'Wolf' Rentzsch: <http://rentzsch.com>
		Some rights reserved: <http://opensource.org/licenses/mit-license.php>

	***************************************************************************/

#import "CoreData+JRExtensions.h"
#import "JRLog.h"

#if NS_BLOCKS_AVAILABLE
@interface JRManagedObjectContextNotificationObserver : NSObject {
    NSManagedObject         *mo;
    JRManagedObjectBlock    block;
}
- (id)initWithManagedObject:(NSManagedObject*)mo_ uponWillDelete:(JRManagedObjectBlock)block_;
@end
#endif

@implementation NSManagedObject (JRExtensions)

+ (id)jr_insertInMoc:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
    
	NSString *entityName = [[[self class] jr_entityDescriptionInMoc:moc_] name];
	return [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:moc_];
}

+ (id)jr_rootObjectInMoc:(NSManagedObjectContext*)moc_ error:(NSError**)error_ {
    NSParameterAssert(moc_);
    
	NSError *error = nil;
	NSArray *objects = [moc_ executeFetchRequest:[self jr_fetchRequestForEntityInMoc:moc_] error:&error];
	NSAssert( objects, @"-[NSManagedObjectContext executeFetchRequest] returned nil" );
	
	id result = nil;
	
	switch( [objects count] ) {
		case 0:
			[[moc_ undoManager] disableUndoRegistration];
			result = [self jr_insertInMoc:moc_];
			[moc_ processPendingChanges];
			[[moc_ undoManager] enableUndoRegistration];
			break;
		case 1:
			result = [objects objectAtIndex:0];
			break;
		default:
			NSAssert2( NO, @"0 or 1 %@ objects expected, %d found", [self className], [objects count] );
	}
	
	if (error_) {
		*error_ = error;
	}
	
	return result;
}

+ (id)jr_rootObjectInMoc:(NSManagedObjectContext*)moc_ {
    NSParameterAssert(moc_);
    
	NSError *error = nil;
	id result = [self jr_rootObjectInMoc:moc_ error:&error];
	if (error) {
        JRLogNSError(error);
		[NSApp presentError:error];
	}
	return result;
}

+ (NSString*)jr_entityNameByHeuristic {
	NSString *result = [self className];
	if( [result hasSuffix:@"MO"] ) {
		result = [result substringToIndex:([result length]-2)];
	}
	return result;
}

+ (NSEntityDescription*)jr_entityDescriptionInMoc:(NSManagedObjectContext*)moc_ {
    NSParameterAssert(moc_);
    
	NSEntityDescription *result = [NSEntityDescription entityForName:[self jr_entityNameByHeuristic] inManagedObjectContext:moc_];
	if (!result) {
		// Heuristic failed. Do it the hard way.
		NSString *className = [self className];
		NSManagedObjectModel *managedObjectModel = [[moc_ persistentStoreCoordinator] managedObjectModel];
		NSArray *entities = [managedObjectModel entities];
		unsigned entityIndex = 0, entityCount = [entities count];
		for(; !result && entityIndex < entityCount; ++entityIndex) {
			if ([[[entities objectAtIndex:entityIndex] managedObjectClassName] isEqualToString:className]) {
				result = [entities objectAtIndex:entityIndex];
			}
		}
		NSAssert1( result, @"no entity found with a managedObjectClassName of %@", className );
	}
	return result;
}

+ (NSFetchRequest*)jr_fetchRequestForEntityInMoc:(NSManagedObjectContext*)moc_ {
    NSParameterAssert(moc_);
    
	NSFetchRequest *result = [[[NSFetchRequest alloc] init] autorelease];
	[result setEntity:[self jr_entityDescriptionInMoc:moc_]];
	NSString *defaultSortKey = [self jr_defaultSortKeyWithMoc:moc_];
	if (defaultSortKey) {
		[result setSortDescriptors:[NSArray arrayWithObject:[[[NSSortDescriptor alloc] initWithKey:defaultSortKey ascending:YES] autorelease]]];
	}
	return result;
}

+ (NSArray*)jr_fetchAll:(NSManagedObjectContext*)moc_ {
    NSParameterAssert(moc_);
    
	NSError *error = nil;
	NSArray *result = [self jr_fetchAll:moc_ error:nil];
	if (error) {
        JRLogNSError(error);
		[NSApp presentError:error];
	}
	return result;
}

+ (NSArray*)jr_fetchAll:(NSManagedObjectContext*)moc_ error:(NSError**)error_ {
    NSParameterAssert(moc_);
    
	return [moc_ executeFetchRequest:[self jr_fetchRequestForEntityInMoc:moc_]
							   error:error_];
}

+ (NSString*)jr_defaultSortKeyWithMoc:(NSManagedObjectContext*)moc_ {
    NSParameterAssert(moc_);
    
	NSString *result = nil;
	NSEntityDescription *entityDesc = [self jr_entityDescriptionInMoc:moc_];
	if (entityDesc) {
		result = [[entityDesc userInfo] objectForKey:@"defaultSortKey"];
		if (!result && [[[entityDesc propertiesByName] allKeys] containsObject:@"position_"]) {
			result = @"position_";
		}
	}
	return result;
}

- (NSString*)jr_objectURLID {
	return [[[self objectID] URIRepresentation] absoluteString];
}

#if NS_BLOCKS_AVAILABLE
- (void)jr_uponWillDelete:(JRManagedObjectBlock)block_ {
    [[JRManagedObjectContextNotificationObserver alloc] initWithManagedObject:self uponWillDelete:block_];
}
#endif

@end

@implementation NSManagedObjectContext (JRExtensions)

- (NSArray*)jr_executeFetchRequestNamed:(NSString*)fetchRequestName_ {
	return [self jr_executeFetchRequestNamed:fetchRequestName_ substitutionVariables:nil];
}

- (NSArray*)jr_executeFetchRequestNamed:(NSString*)fetchRequestName_ error:(NSError**)error_ {
	return [self jr_executeFetchRequestNamed:fetchRequestName_ substitutionVariables:nil error:error_];
}

- (NSArray*)jr_executeFetchRequestNamed:(NSString*)fetchRequestName_ substitutionVariables:(NSDictionary*)variables_ {
	NSError *error = nil;
	NSArray *result = [self jr_executeFetchRequestNamed:fetchRequestName_ substitutionVariables:variables_ error:&error];
	if (error) {
        JRLogNSError(error);
		[NSApp presentError:error];
	}
	return result;
}

#define FetchRequestSortDescriptorsSeemsBroken	1

- (NSArray*)jr_executeFetchRequestNamed:(NSString*)fetchRequestName_ substitutionVariables:(NSDictionary*)variables_ error:(NSError**)error_ {
	NSManagedObjectModel *model = [[self persistentStoreCoordinator] managedObjectModel];
	NSFetchRequest *fetchRequest = [model fetchRequestFromTemplateWithName:fetchRequestName_
													 substitutionVariables:variables_ ? variables_ : [NSDictionary dictionary]];
	NSAssert1(fetchRequest, @"Can't find fetch request named \"%@\".", fetchRequestName_);
	
	NSString *defaultSortKey = nil;
	Class entityClass = NSClassFromString([[fetchRequest entity] managedObjectClassName]);
	if ([entityClass respondsToSelector:@selector(defaultSortKeyWithManagedObjectContext:)]) {
		defaultSortKey = [entityClass jr_defaultSortKeyWithMoc:self];
	}
	
#if !FetchRequestSortDescriptorsSeemsBroken
	if (defaultSortKey) {
		NSAssert([[fetchRequest sortDescriptors] count] == 0, @"Model-based fetch requests can't have sortDescriptors.");
		[fetchRequest setSortDescriptors:[NSArray arrayWithObject:[[[NSSortDescriptor alloc] initWithKey:defaultSortKey ascending:YES] autorelease]]];
	}
#endif
	
	NSArray *result = [self executeFetchRequest:fetchRequest error:error_];
	
#if FetchRequestSortDescriptorsSeemsBroken
	if (defaultSortKey) {
		result = [result sortedArrayUsingDescriptors:[NSArray arrayWithObject:[[[NSSortDescriptor alloc] initWithKey:defaultSortKey ascending:YES] autorelease]]];
	}
#endif
	return result;
}

- (id)jr_executeSingleResultFetchRequestNamed:(NSString*)fetchRequestName_ substitutionVariables:(NSDictionary*)variables_ error:(NSError**)error_ {
	id		result = nil;
	NSError	*error = nil;
	
	NSArray *objects = [self jr_executeFetchRequestNamed:fetchRequestName_ substitutionVariables:variables_ error:&error];
	NSAssert(objects, nil);
	
	if (!error) {
		switch ([objects count]) {
			case 0:
				//	Nothing found matching the fetch request. That's cool, though: we'll just return nil.
				break;
			case 1:
				result = [objects objectAtIndex:0];
				break;
			default:
				NSAssert2(NO, @"%@: 0 or 1 objects expected, %u found", fetchRequestName_, [objects count]);
		}
	}
	
	if (error_) *error_ = error;
	return result;
}

- (id)jr_objectWithURLID:(NSString*)url_ {
	NSParameterAssert(url_);
    
	NSURL *url = [NSURL URLWithString:url_];
	NSAssert1(url, @"[NSURL URLWithString:@\"%@\"] failed", url_);
	NSManagedObjectID *objectID = [[self persistentStoreCoordinator] managedObjectIDForURIRepresentation:url];
	return objectID ? [self objectRegisteredForID:objectID] : nil;
}

@end

@implementation NSNotification (JRExtensions)

- (NSSet*)jr_insertedObjects {
    return [[self userInfo] objectForKey:NSInsertedObjectsKey];
}

- (NSSet*)jr_updatedObjects {
    NSSet           *supposedlyUpdatedObjects = [[self userInfo] objectForKey:NSUpdatedObjectsKey];
    NSMutableSet    *actuallyUpdatedObjects = nil;
    
    for (NSManagedObject *supposedlyUpdatedObject in supposedlyUpdatedObjects) {
        if ([[supposedlyUpdatedObject changedValues] count]) {
            if (!actuallyUpdatedObjects) {
                actuallyUpdatedObjects = [NSMutableSet setWithCapacity:[supposedlyUpdatedObjects count]];
            }
            [actuallyUpdatedObjects addObject:supposedlyUpdatedObject];
        }
    }
    
    return actuallyUpdatedObjects;
}

- (NSSet*)jr_deletedObjects {
    return [[self userInfo] objectForKey:NSDeletedObjectsKey];
}

- (NSSet*)jr_deletedObjectsOfClass:(Class)cls_ {
    NSSet *deletedObjects = [self jr_deletedObjects];
    NSMutableSet *result = nil;
    for (NSManagedObject *deletedObject in deletedObjects) {
        if ([deletedObject isKindOfClass:cls_]) {
            if (!result) {
                result = [NSMutableSet setWithCapacity:[deletedObjects count]];
            }
            [result addObject:deletedObject];
        }
    }
    return result;
}

@end

#if NS_BLOCKS_AVAILABLE
@implementation JRManagedObjectContextNotificationObserver

- (id)initWithManagedObject:(NSManagedObject*)mo_ uponWillDelete:(JRManagedObjectBlock)block_ {
    NSParameterAssert(mo_);
    NSParameterAssert(block_);
    
    self = [super init];
    if (self) {
        mo = [mo_ retain];
        block = [block_ copy];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(mocObjectsDidChange:)
                                                     name:NSManagedObjectContextObjectsDidChangeNotification
                                                   object:[mo_ managedObjectContext]];
    }
    return self;
}

- (void)dealloc {
    [mo release];
    [block release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)settingsDidChange:(NSNotification*)notification_ {
    NSArray *deletedObjects = [[notification_ userInfo] objectForKey:NSDeletedObjectsKey];
    
    if ([deletedObjects containsObject:mo]) {
        block(mo);
        [self autorelease];
    }
}

@end
#endif